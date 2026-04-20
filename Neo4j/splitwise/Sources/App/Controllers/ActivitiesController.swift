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

    // Check if the payer is already registered
    if try await checkIfRegistered(name: activity.payer) == false {
      throw HTTPError(.notFound, message: "\(activity.payer) has not been registered yet.")
    }

    // Check if the participant(s) is/are already resgistered
    for participant in activity.participants {
      if try await checkIfRegistered(name: participant) == false {
        throw HTTPError(.notFound, message: "\(participant) has not been registered yet.")
      }
    }

    // Create the activity
    /// `MATCH (alice:FRIEND {name: 'Alice'}),
    ///        (bob:FRIEND {name: 'Bob'}),
    ///        (charles:FRIEND {name: 'Charles'}),
    ///        (event:EVENT {eventID: '7C448FD5-...'})
    /// CREATE (coffee:ACTIVITY {
    ///   activityID: '...',
    ///   name: 'Coffee',
    ///   date: date('2026-02-02'),
    ///   totalAmount: 25.5,
    ///   currency: 'EUR'
    /// })
    /// CREATE (bob)-[:PAID_FOR {amount: 25.5}]->(coffee),
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
      "name": .string(activity.name),
      "date": .date(activity.dateString),
      "totalAmount": .double(activity.amount),
      "currency": .string(activity.currency),
    ]
    for (i, name) in allPeople.enumerated() {
      parameters["name\(i)"] = .string(name)
    }

    let statement = """
      MATCH \(friendMatches),
            (event:EVENT {eventID: $eventID})
      CREATE (activity:ACTIVITY {
        activityID: $activityID,
        name: $name,
        date: $date,
        totalAmount: $totalAmount,
        currency: $currency
      })
      CREATE (p0)-[:PAID_FOR {amount: $totalAmount}]->(activity),
             \(participantRels),
             (activity)-[:BELONGS_TO]->(event)
      """

    let queryRequest = QueryRequest(statement: statement, parameters: parameters)
    _ = try await client.runQuery(request: queryRequest)

    return .created
  }

  // MARK: - index
  /// `curl "http://localhost:8080/api/v1/activities"`
  /// Expected response:
  /// ```json
  /// [
  ///   {
  ///     "activityID": "E86B09EF-76AC-41D8-9D2C-163F30188FBF",
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
    /// RETURN n, e.eventID AS eventID, payer.name AS payerName, collect(participant.name) AS participants
    /// ```
    let statement = """
      MATCH (n:ACTIVITY)-[:BELONGS_TO]->(e:EVENT)
      MATCH (payer:FRIEND)-[:PAID_FOR]->(n)
      MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(n)
      RETURN n, e.eventID AS eventID, payer.name AS payerName, collect(participant.name) AS participants
      """
    let queryRequest = QueryRequest(statement: statement)
    let response = try await client.runQuery(request: queryRequest)

    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let activityIdString = node.properties["activityID"]?.stringValue,
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

  // MARK: - Shared function to check that person/people in the user input already registered.
  private func checkIfRegistered(name: String) async throws -> Bool {
    /// `MATCH (n:FRIEND {name: 'Bob'}) RETURN count(n) > 0 AS exists;`
    let queryRequest = QueryRequest(statement: "MATCH (n:FRIEND {name: $name}) RETURN count(n) > 0 AS exists", parameters: ["name": .string("\(name)")])
    let response = try await client.runQuery(request: queryRequest)
    return response.rows.first?["exists"]?.boolValue ?? false
  }
}
