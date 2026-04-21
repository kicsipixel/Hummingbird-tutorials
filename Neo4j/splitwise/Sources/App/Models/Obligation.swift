import Hummingbird

struct Obligation: Codable {
  let payer: String
  let participant: String
  let event: String
  let owes: Double
  let currency: String
}

extension Obligation: ResponseCodable {}
