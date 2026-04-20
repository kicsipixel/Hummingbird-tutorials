import Foundation
import Hummingbird

struct Activity: Codable {
  let activityID: UUID
  let name: String
  let dateString: String
  let amount: Double
  let currency: String
  let eventID: UUID
  let payer: String
  let participants: [String]

  enum CodingKeys: String, CodingKey {
    case activityID
    case name
    case dateString = "date"
    case amount
    case currency
    case eventID = "event_id"
    case payer
    case participants
  }
}

extension Activity {
  struct Create: Codable {
    let name: String
    let dateString: String
    let amount: Double
    let currency: String
    let eventID: String
    let payer: String
    let participants: [String]

    enum CodingKeys: String, CodingKey {
      case name
      case dateString = "date"
      case amount
      case currency
      case eventID = "event_id"
      case payer
      case participants
    }
  }
}

extension Activity: ResponseCodable {}
