import Foundation
import Hummingbird

struct Friend: Codable {
  let friendID: UUID
  let name: String
}

extension Friend {
  struct Create: Codable {
    let name: String
  }
}

extension Friend: ResponseCodable {}
