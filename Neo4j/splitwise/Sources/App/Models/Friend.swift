import Foundation
import Hummingbird

struct Friend: Codable {
  let friendID: UUID
  let name: String

  enum CodingKeys: String, CodingKey {
    case friendID = "friend_id"
    case name
  }
}

extension Friend {
  struct Create: Codable {
    let name: String
  }
}

extension Friend: ResponseCodable {}
