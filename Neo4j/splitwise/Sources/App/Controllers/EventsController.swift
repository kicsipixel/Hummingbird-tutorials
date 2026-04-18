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
    ///    eventID: '2DB325DC-6884-40EB-8ECB-8695641746DD'
    ///    name: 'Skiing in Tirol',
    ///    start_date: date('2026-02-01'),
    ///    end_date: date('2026-02-03'),
    ///    description: 'Weekend trip to the mountains'
    ///  })`
    let queryRequest = QueryRequest(
      statement: "CREATE (event:EVENT {eventID: $eventID, name: $name, start_date: date($start_date), end_date: date($end_date), description: $description})",
      parameters: [
        "eventID": .string(UUID().uuidString),
        "name": .string(event.name),
        "start_date": .string(event.startDateString),
        "end_date": .string(event.endDateString),
        "description": .string(event.description),
      ]
    )
    _ = try await client.runQuery(request: queryRequest)

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
        let eventIdString = node.properties["eventID"]?.stringValue,
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
  ///
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Event {
    let eventID = try context.parameters.require("eventID", as: String.self)

    /// `MATCH (n:EVENT {eventID: '2DB325DC-6884-40EB-8ECB-8695641746DD'}) RETURN n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:EVENT {eventID: $eventID}) RETURN n",
      parameters: [
        "eventID": .string(eventID)
      ]
    )

    let response = try await client.runQuery(request: queryRequest)

    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let eventIdString = node.properties["eventID"]?.stringValue,
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
}
