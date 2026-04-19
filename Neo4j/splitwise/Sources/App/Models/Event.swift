import Foundation
import Hummingbird

struct Event: Codable {
  let eventID: UUID
  let name: String
  let startDateString: String
  let endDateString: String
  let description: String

  var startDate: Date? {
    let formatter = DateFormatter()
    formatter.locale = .init(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: startDateString)
  }

  var endDate: Date? {
    let formatter = DateFormatter()
    formatter.locale = .init(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: endDateString)
  }

  enum CodingKeys: String, CodingKey {
    case eventID
    case name
    case startDateString = "start_date"
    case endDateString = "end_date"
    case description
  }
}

extension Event {
  struct Create: Codable {
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
