import Foundation
import Hummingbird

struct Activity: Codable {
  let name: String
  let payer: String
  let participants: [String]
  let item: String
  let dateString: String
  let amount: Double
  let currency: String

  enum CodingKeys: String, CodingKey {
    case name
    case dateString = "date"
    case payer
    case participants
    case item
    case amount
    case currency
  }
}

extension Activity: ResponseCodable {}
