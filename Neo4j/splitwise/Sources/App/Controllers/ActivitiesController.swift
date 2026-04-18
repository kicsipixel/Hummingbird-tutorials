import Hummingbird
import Logging
import SwiftCypher

struct ActivitiesController<Context: RequestContext> {
  let client: SwiftCypherClient
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: create)
    //  .get(use: index)
  }

  // MARK: - create
  @Sendable
  func create(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let activity = try await request.decode(as: Activity.self, context: context)

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
    ///     (bob:FRIEND {name: 'Bob'}),
    ///     (charles:FRIEND {name: 'Charles'}),
    ///      (event:EVENT {name: 'Skiing in Tirol'})
    /// CREATE (coffee:ACTIVITY {
    ///   item: 'Coffee',
    ///   date: date('2026-02-01'),
    ///   totalAmount: 15.00,
    ///    currency: 'EUR'
    ///  })
    ///  CREATE (bob)-[:PAID_FOR {amount: 15.00}]->(coffee),
    ///         (alice)-[:PARTICIPATED_IN]->(coffee),
    ///         (charles)-[:PARTICIPATED_IN]->(coffee),
    ///         (coffee)-[:BELONGS_TO]->(event)`

    // p0 = payer, p1..pN = participants
    let allPeople = [activity.payer] + activity.participants

    let matchLines = allPeople.enumerated()
      .map { i, _ in "(p\(i):FRIEND {name: $name\(i)})" }
      .joined(separator: ",\n      ")

    let participantRels = activity.participants.enumerated()
      .map { i, _ in "(p\(i + 1))-[:PARTICIPATED_IN]->(act)" }
      .joined(separator: ",\n       ")

    var parameters: [String: Neo4jValue] = [
      "item": .string(activity.item),
      "date": .string(activity.dateString),
      "totalAmount": .double(Double(activity.amount)),
      "currency": .string(activity.currency),
    ]
    for (i, name) in allPeople.enumerated() {
      parameters["name\(i)"] = .string(name)
    }

    let statement = """
      MATCH \(matchLines)
      CREATE (act:ACTIVITY {
        item: $item,
        date: date($date),
        totalAmount: $totalAmount,
        currency: $currency
      })
      CREATE (p0)-[:PAID_FOR {amount: $totalAmount}]->(act),
             \(participantRels)
      """

    let queryRequest = QueryRequest(statement: statement, parameters: parameters)
    _ = try await client.runQuery(request: queryRequest)

    return .created
  }

  // MARK: - Shared function to check that person/people in the user input already registered.
  private func checkIfRegistered(name: String) async throws -> Bool {
    /// `MATCH (n:FRIEND {name: 'Bob'}) RETURN count(n) > 0 AS exists;`
    let queryRequest = QueryRequest(statement: "MATCH (n:FRIEND {name: $name}) RETURN count(n) > 0 AS exists", parameters: ["name": .string("\(name)")])
    let response = try await client.runQuery(request: queryRequest)
    return response.rows.first?["exists"]?.boolValue ?? false
  }
}
