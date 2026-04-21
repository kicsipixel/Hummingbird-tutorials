import Foundation
import Hummingbird
import Logging
import SwiftCypher

struct EventsController<Context: RequestContext> {
  let client: SwiftCypherClient
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: create)
      .get(use: index)
      .get(":eventID", use: show)
      .patch(":eventID", use: edit)
      .delete(":eventID", use: delete)
  }

  // MARK: - create
  /// curl -X "POST" "http://localhost:8080/api/v1/events" \
  ///   -H 'Content-Type: text/plain; charset=utf-8' \
  ///   -d $'{
  ///     "name": "Skiing in Tirol",
  ///     "start_date": "2026-02-01",
  ///     "end_date": "2026-02-03",
  ///     "description": "Weekend trip to the mountains"
  ///   }'
  @Sendable
  func create(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let event = try await request.decode(as: Event.Create.self, context: context)

    /// `CREATE (event:EVENT {
    ///    event_id: $eventID,
    ///    name: $name,
    ///    start_date: date($start_date),
    ///    end_date: date($end_date),
    ///    description: $description
    ///  })`
    let queryRequest = QueryRequest(
      statement: "CREATE (event:EVENT {event_id: $eventID, name: $name, start_date: date($start_date), end_date: date($end_date), description: $description})",
      parameters: [
        "eventID": .string(UUID().uuidString),
        "name": .string(event.name),
        "start_date": .string(event.startDateString),
        "end_date": .string(event.endDateString),
        "description": .string(event.description),
      ]
    )
    do {
      _ = try await client.runQuery(request: queryRequest)
    }
    catch {
      logger.error("Neo4j error in EventsController.create: \(error)")
      throw error
    }

    return .created
  }

  // MARK: - index
  /// `curl "http://localhost:8080/api/v1/events"`
  @Sendable
  func index(_ request: Request, context: Context) async throws -> [Event] {
    var events = [Event]()

    /// `MATCH (n:EVENT) RETURN n`
    let queryRequest = QueryRequest(statement: "MATCH (n:EVENT) RETURN n")
    let response = try await client.runQuery(request: queryRequest)

    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let eventIdString = node.properties["event_id"]?.stringValue,
        let eventID = UUID(uuidString: eventIdString),
        let name = node.properties["name"]?.stringValue,
        let startDate = node.properties["start_date"]?.dateValue,
        let endDate = node.properties["end_date"]?.dateValue,
        let description = node.properties["description"]?.stringValue
      {
        events.append(Event(eventID: eventID, name: name, startDateString: startDate, endDateString: endDate, description: description))
      }
    }

    return events
  }

  // MARK: - show
  /// `curl "http://localhost:8080/api/v1/events/4BFC90F2-D154-4228-B55A-469B1823FF8E"`
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Event {
    let eventID = try context.parameters.require("eventID", as: String.self)

    /// `MATCH (n:EVENT {event_id: '2DB325DC-6884-40EB-8ECB-8695641746DD'}) RETURN n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:EVENT {event_id: $eventID}) RETURN n",
      parameters: ["eventID": .string(eventID)]
    )

    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let eventIdString = node.properties["event_id"]?.stringValue,
        let eventID = UUID(uuidString: eventIdString),
        let name = node.properties["name"]?.stringValue,
        let startDate = node.properties["start_date"]?.dateValue,
        let endDate = node.properties["end_date"]?.dateValue,
        let description = node.properties["description"]?.stringValue
      {
        return Event(eventID: eventID, name: name, startDateString: startDate, endDateString: endDate, description: description)
      }
    }
    throw HTTPError(.notFound, message: "The event with id:\(eventID) was not found")
  }

  // MARK: - edit
  /// curl -X "PATCH" "http://localhost:8080/api/v1/events/4BFC90F2-D154-4228-B55A-469B1823FF8E" \
  ///   -H 'Content-Type: application/json' \
  ///   -d $'{"name": "Skiing in Austria"}'
  @Sendable
  func edit(_ request: Request, context: Context) async throws -> Event {
    let eventID = try context.parameters.require("eventID", as: String.self)
    let patch = try await request.decode(as: Event.Edit.self, context: context)

    // Fetch original
    /// `MATCH (n:EVENT {event_id: '4BFC90F2-D154-4228-B55A-469B1823FF8E'}) RETURN n`
    let fetchRequest = QueryRequest(
      statement: "MATCH (n:EVENT {event_id: $eventID}) RETURN n",
      parameters: ["eventID": .string(eventID)]
    )
    let fetchResponse = try await client.runQuery(request: fetchRequest)

    guard let row = fetchResponse.rows.first,
      let node = row["n"]?.nodeValue,
      let originalEventIdString = node.properties["event_id"]?.stringValue,
      let originalEventID = UUID(uuidString: originalEventIdString),
      let originalName = node.properties["name"]?.stringValue,
      let originalStartDate = node.properties["start_date"]?.dateValue,
      let originalEndDate = node.properties["end_date"]?.dateValue,
      let originalDescription = node.properties["description"]?.stringValue
    else {
      throw HTTPError(.notFound, message: "The event with id:\(eventID) was not found")
    }

    let updatedName = patch.name ?? originalName
    let updatedStartDate = patch.startDateString ?? originalStartDate
    let updatedEndDate = patch.endDateString ?? originalEndDate
    let updatedDescription = patch.description ?? originalDescription

    /// `MATCH (n:EVENT {event_id: '4BFC90F2-D154-4228-B55A-469B1823FF8E'}) SET n.name = $name, n.start_date = date($start_date), n.end_date = date($end_date), n.description = $description`
    let updateRequest = QueryRequest(
      statement: "MATCH (n:EVENT {event_id: $eventID}) SET n.name = $name, n.start_date = date($start_date), n.end_date = date($end_date), n.description = $description",
      parameters: [
        "eventID": .string(eventID),
        "name": .string(updatedName),
        "start_date": .string(updatedStartDate),
        "end_date": .string(updatedEndDate),
        "description": .string(updatedDescription),
      ]
    )
    _ = try await client.runQuery(request: updateRequest)

    return Event(eventID: originalEventID, name: updatedName, startDateString: updatedStartDate, endDateString: updatedEndDate, description: updatedDescription)
  }

  // MARK: - delete
  /// `curl -X "DELETE" "http://localhost:8080/api/v1/events/4BFC90F2-D154-4228-B55A-469B1823FF8E"`
  @Sendable
  func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let eventID = try context.parameters.require("eventID", as: String.self)

    /// `MATCH (n:EVENT {event_id: '4BFC90F2-D154-4228-B55A-469B1823FF8E'}) DETACH DELETE n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:EVENT {event_id: $eventID}) DETACH DELETE n",
      parameters: ["eventID": .string(eventID)]
    )
    let response = try await client.runQuery(request: queryRequest)

    guard response.counters?.nodesDeleted ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "The event with id:\(eventID) was not found")
    }
    return .noContent
  }
}
