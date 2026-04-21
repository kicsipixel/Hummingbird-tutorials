import Foundation
import Hummingbird
import Logging
import SwiftCypher

struct ActivitiesController<Context: RequestContext> {
  let client: SwiftCypherClient
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: create)
      .get(use: index)
      .get(":activityID", use: show)
      .patch(":activityID", use: edit)
      .delete(":activityID", use: delete)
  }

  // MARK: - create
  /// `curl -X "POST" "http://localhost:8080/api/v1/activities" \
  ///       -H 'Content-Type: application/json' \
  ///       -d $'{
  ///     "amount": 25.5,
  ///     "date": "2026-02-02",
  ///     "participants": [
  ///       "Alice",
  ///       "Charles"
  ///     ],
  ///     "event_id": "7C448FD5-8DB1-44DA-92EB-9462BADE515C",
  ///     "payer": "Bob",
  ///     "name": "Coffee",
  ///     "currency": "EUR"
  ///   }'`
  @Sendable
  func create(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let activity = try await request.decode(as: Activity.Create.self, context: context)

    /// `MATCH (alice:FRIEND {name: 'Alice'}),
    ///        (bob:FRIEND {name: 'Bob'}),
    ///        (charles:FRIEND {name: 'Charles'}),
    ///        (event:EVENT {event_id: '7C448FD5-...'})
    /// CREATE (coffee:ACTIVITY {
    ///   activity_id: '...',
    ///   name: $nameValue,
    ///   date: $date,
    ///   totalAmount: $totalAmount,
    ///   currency: $currency
    /// })
    /// CREATE (bob)-[:PAID_FOR {amount: $totalAmount}]->(coffee),
    ///        (alice)-[:PARTICIPATED_IN]->(coffee),
    ///        (charles)-[:PARTICIPATED_IN]->(coffee),
    ///        (coffee)-[:BELONGS_TO]->(event)`

    // p0 = payer, p1..pN = participants
    let allPeople = [activity.payer] + activity.participants

    let friendMatches = allPeople.enumerated()
      .map { i, _ in "(p\(i):FRIEND {name: $name\(i)})" }
      .joined(separator: ",\n      ")

    let participantRels = activity.participants.enumerated()
      .map { i, _ in "(p\(i + 1))-[:PARTICIPATED_IN]->(activity)" }
      .joined(separator: ",\n       ")

    var parameters: [String: Neo4jValue] = [
      "activityID": .string(UUID().uuidString),
      "eventID": .string(activity.eventID),
      "nameValue": .string(activity.name),
      "date": .date(activity.dateString),
      "totalAmount": .double(activity.amount),
      "currency": .string(activity.currency),
    ]
    for (i, name) in allPeople.enumerated() {
      parameters["name\(i)"] = .string(name)
    }

    let statement = """
      MATCH \(friendMatches),
            (event:EVENT {event_id: $eventID})
      CREATE (activity:ACTIVITY {
        activity_id: $activityID,
        name: $nameValue,
        date: $date,
        totalAmount: $totalAmount,
        currency: $currency
      })
      CREATE (p0)-[:PAID_FOR {amount: $totalAmount}]->(activity),
             \(participantRels),
             (activity)-[:BELONGS_TO]->(event)
      """

    let queryRequest = QueryRequest(statement: statement, parameters: parameters)
    let response = try await client.runQuery(request: queryRequest)
    guard response.counters?.nodesCreated ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "One or more friends or the event were not found.")
    }

    return .created
  }

  // MARK: - index
  /// `curl "http://localhost:8080/api/v1/activities"`
  /// Expected response:
  /// ```json
  /// [
  ///   {
  ///     "activity_id": "E86B09EF-76AC-41D8-9D2C-163F30188FBF",
  ///     "name": "Coffee",
  ///     "date": "2026-02-02",
  ///     "amount": 25.5,
  ///     "currency": "EUR",
  ///     "event_id": "7C448FD5-8DB1-44DA-92EB-9462BADE515C",
  ///     "payer": "Bob",
  ///     "participants": ["Alice", "Charles"]
  ///   }
  /// ]
  /// ```
  @Sendable
  func index(_ request: Request, context: Context) async throws -> [Activity] {
    var activities = [Activity]()

    /// ```
    /// MATCH (n:ACTIVITY)-[:BELONGS_TO]->(e:EVENT)
    /// MATCH (payer:FRIEND)-[:PAID_FOR]->(n)
    /// MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)
    /// RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants
    /// ```
    let statement = """
      MATCH (n:ACTIVITY)-[:BELONGS_TO]->(e:EVENT)
      MATCH (payer:FRIEND)-[:PAID_FOR]->(n)
      MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)
      RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants
      """
    let queryRequest = QueryRequest(statement: statement)
    let response = try await client.runQuery(request: queryRequest)

    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let activityIdString = node.properties["activity_id"]?.stringValue,
        let activityID = UUID(uuidString: activityIdString),
        let name = node.properties["name"]?.stringValue,
        let dateString = node.properties["date"]?.dateValue,
        let amount = node.properties["totalAmount"]?.doubleValue,
        let currency = node.properties["currency"]?.stringValue,
        let eventIdString = row["eventID"]?.stringValue,
        let eventID = UUID(uuidString: eventIdString),
        let payerName = row["payerName"]?.stringValue
      {
        let participantNames = row["participants"]?.listValue?.compactMap { $0.stringValue } ?? []
        activities.append(
          Activity(
            activityID: activityID,
            name: name,
            dateString: dateString,
            amount: amount,
            currency: currency,
            eventID: eventID,
            payer: payerName,
            participants: participantNames
          )
        )
      }
    }

    return activities
  }

  // MARK: - show
  /// `curl "http://localhost:8080/api/v1/activities/E86B09EF-76AC-41D8-9D2C-163F30188FBF"`
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Activity {
    let activityID = try context.parameters.require("activityID", as: String.self)

    /// `MATCH (n:ACTIVITY {activity_id: $activityID})-[:BELONGS_TO]->(e:EVENT)`
    /// `MATCH (payer:FRIEND)-[:PAID_FOR]->(n)`
    /// `MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)`
    /// `RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants`
    let queryRequest = QueryRequest(
      statement: """
        MATCH (n:ACTIVITY {activity_id: $activityID})-[:BELONGS_TO]->(e:EVENT)
        MATCH (payer:FRIEND)-[:PAID_FOR]->(n)
        MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)
        RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants
        """,
      parameters: ["activityID": .string(activityID)]
    )

    let response = try await client.runQuery(request: queryRequest)

    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let activityIdString = node.properties["activity_id"]?.stringValue,
        let activityID = UUID(uuidString: activityIdString),
        let name = node.properties["name"]?.stringValue,
        let dateString = node.properties["date"]?.dateValue,
        let amount = node.properties["totalAmount"]?.doubleValue,
        let currency = node.properties["currency"]?.stringValue,
        let eventIdString = row["eventID"]?.stringValue,
        let eventID = UUID(uuidString: eventIdString),
        let payerName = row["payerName"]?.stringValue
      {
        let participantNames = row["participants"]?.listValue?.compactMap { $0.stringValue } ?? []
        return Activity(
          activityID: activityID,
          name: name,
          dateString: dateString,
          amount: amount,
          currency: currency,
          eventID: eventID,
          payer: payerName,
          participants: participantNames
        )
      }
    }
    throw HTTPError(.notFound, message: "Activity with id:\(activityID) was not found.")
  }

  // MARK: - edit
  /// `curl -X "PATCH" "http://localhost:8080/api/v1/activities/E86B09EF-76AC-41D8-9D2C-163F30188FBF" \
  ///       -H 'Content-Type: application/json' \
  ///       -d $'{"name": "Tea", "amount": 5.0}'`
  @Sendable
  func edit(_ request: Request, context: Context) async throws -> Activity {
    let activityID = try context.parameters.require("activityID", as: String.self)
    let patch = try await request.decode(as: Activity.Edit.self, context: context)

    // Fetch current activity
    /// `MATCH (n:ACTIVITY {activity_id: $activityID})-[:BELONGS_TO]->(e:EVENT)`
    /// `MATCH (payer:FRIEND)-[:PAID_FOR]->(n)`
    /// `MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)`
    /// `RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants`
    let fetchRequest = QueryRequest(
      statement: """
        MATCH (n:ACTIVITY {activity_id: $activityID})-[:BELONGS_TO]->(e:EVENT)
        MATCH (payer:FRIEND)-[:PAID_FOR]->(n)
        MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)
        RETURN n, e.event_id AS eventID, payer.name AS payerName, collect(participant.name) AS participants
        """,
      parameters: ["activityID": .string(activityID)]
    )
    let fetchResponse = try await client.runQuery(request: fetchRequest)

    guard let row = fetchResponse.rows.first,
      let node = row["n"]?.nodeValue,
      let originalActivityIdString = node.properties["activity_id"]?.stringValue,
      let originalActivityID = UUID(uuidString: originalActivityIdString),
      let originalName = node.properties["name"]?.stringValue,
      let originalDate = node.properties["date"]?.dateValue,
      let originalAmount = node.properties["totalAmount"]?.doubleValue,
      let originalCurrency = node.properties["currency"]?.stringValue,
      let eventIdString = row["eventID"]?.stringValue,
      let eventID = UUID(uuidString: eventIdString),
      let payerName = row["payerName"]?.stringValue
    else {
      throw HTTPError(.notFound, message: "Activity with id:\(activityID) was not found.")
    }

    let participantNames = row["participants"]?.listValue?.compactMap { $0.stringValue } ?? []
    let updatedName = patch.name ?? originalName
    let updatedDate = patch.dateString ?? originalDate
    let updatedAmount = patch.amount ?? originalAmount
    let updatedCurrency = patch.currency ?? originalCurrency

    /// `MATCH (n:ACTIVITY {activity_id: $activityID})`
    /// `SET n.name = $nameValue, n.date = date($date), n.totalAmount = $totalAmount, n.currency = $currency`
    let updateRequest = QueryRequest(
      statement: "MATCH (n:ACTIVITY {activity_id: $activityID}) SET n.name = $nameValue, n.date = date($date), n.totalAmount = $totalAmount, n.currency = $currency",
      parameters: [
        "activityID": .string(activityID),
        "nameValue": .string(updatedName),
        "date": .string(updatedDate),
        "totalAmount": .double(updatedAmount),
        "currency": .string(updatedCurrency),
      ]
    )
    _ = try await client.runQuery(request: updateRequest)

    return Activity(
      activityID: originalActivityID,
      name: updatedName,
      dateString: updatedDate,
      amount: updatedAmount,
      currency: updatedCurrency,
      eventID: eventID,
      payer: payerName,
      participants: participantNames
    )
  }

  // MARK: - delete
  /// `curl -X "DELETE" "http://localhost:8080/api/v1/activities/E86B09EF-76AC-41D8-9D2C-163F30188FBF"`
  @Sendable
  func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let activityID = try context.parameters.require("activityID", as: String.self)

    /// `MATCH (n:ACTIVITY {activity_id: '...'}) DETACH DELETE n`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:ACTIVITY {activity_id: $activityID}) DETACH DELETE n",
      parameters: ["activityID": .string(activityID)]
    )
    let response = try await client.runQuery(request: queryRequest)

    guard response.counters?.nodesDeleted ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "Activity with id:\(activityID) was not found.")
    }
    return .noContent
  }

}
