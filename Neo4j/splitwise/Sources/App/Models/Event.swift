import Foundation
import Hummingbird

struct Event: Codable {
  let eventID: UUID
  let name: String
  let startDateString: String
  let endDateString: String
  let description: String

  enum CodingKeys: String, CodingKey {
    case eventID = "event_id"
    case name
    case startDateString = "start_date"
    case endDateString = "end_date"
    case description
  }
}

extension Event {
  struct Create: Codable {
    let name: String
    let startDateString: String
    let endDateString: String
    let description: String

    enum CodingKeys: String, CodingKey {
      case name
      case startDateString = "start_date"
      case endDateString = "end_date"
      case description
    }
  }
}

extension Event {
  struct Edit: Codable {
    let name: String?
    let startDateString: String?
    let endDateString: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
      case name
      case startDateString = "start_date"
      case endDateString = "end_date"
      case description
    }
  }
}

extension Event: ResponseCodable {}
