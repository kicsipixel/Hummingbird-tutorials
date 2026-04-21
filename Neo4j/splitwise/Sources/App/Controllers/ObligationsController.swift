import Hummingbird
import Logging
import SwiftCypher

struct ObligationsController<Context: RequestContext> {
  let client: SwiftCypherClient
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .get(":eventID", use: show)
  }

  // MARK: - show
  /// Returns obligations consolidated for a specific event
  /// `curl "http://localhost:8080/api/v1/obligations/0ADA5DAA-269E-4732-AF7C-12037AF72121"`
  @Sendable
  func show(_ request: Request, context: Context) async throws -> [Obligation] {
    let eventID = try context.parameters.require("eventID", as: String.self)
    var obligations = [Obligation]()

    ///   MATCH (activity:ACTIVITY)-[:BELONGS_TO]->(event:EVENT)
    ///   WHERE event.event_id = $eventID
    ///   MATCH (payer:FRIEND)-[:PAID_FOR]->(activity)
    ///   MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(activity)
    ///   WITH event.name AS eventName, payer.name AS payerName, activity, activity.currency AS currency,
    ///        collect(participant.name) AS participantNames
    ///   WITH eventName, payerName, currency, participantNames,
    ///        size(participantNames) AS numParticipants, activity.totalAmount AS amount
    ///   UNWIND participantNames AS participantName
    ///   WITH eventName, payerName, participantName, currency, amount / (numParticipants + 1) AS share
    ///   WITH eventName, payerName, participantName, currency, sum(share) AS owes
    ///   RETURN { event: eventName, payer: payerName, participant: participantName, owes: owes, currency: currency } AS obligation
    ///   ORDER BY payerName, participantName
    let queryRequest = QueryRequest(
      statement: """
        MATCH (activity:ACTIVITY)-[:BELONGS_TO]->(event:EVENT)
        WHERE event.event_id = $eventID
        MATCH (payer:FRIEND)-[:PAID_FOR]->(activity)
        MATCH (participant:FRIEND)-[:PARTICIPATED_IN]->(activity)
        WITH event.name AS eventName, payer.name AS payerName, activity, activity.currency AS currency,
             collect(participant.name) AS participantNames
        WITH eventName, payerName, currency, participantNames,
             size(participantNames) AS numParticipants, activity.totalAmount AS amount
        UNWIND participantNames AS participantName
        WITH eventName, payerName, participantName, currency, amount / (numParticipants + 1) AS share
        WITH eventName, payerName, participantName, currency, sum(share) AS owes
        RETURN {
          event: eventName,
          payer: payerName,
          participant: participantName,
          owes: owes,
          currency: currency
        } AS obligation
        ORDER BY payerName, participantName
        """,
      parameters: ["eventID": .string(eventID)]
    )
    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let obligation = row["obligation"]?.mapValue {
        let payer = obligation["payer"]?.stringValue ?? "N/A"
        let participant = obligation["participant"]?.stringValue ?? "N/A"
        let event = obligation["event"]?.stringValue ?? "N/A"
        let owes = ((obligation["owes"]?.doubleValue ?? 0.0) * 100).rounded() / 100
        let currency = obligation["currency"]?.stringValue ?? "N/A"

        obligations.append(
          Obligation(payer: payer, participant: participant, event: event, owes: owes, currency: currency)
        )
      }
    }

    return obligations
  }
}
