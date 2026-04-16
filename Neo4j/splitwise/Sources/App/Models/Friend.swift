import Hummingbird

struct Friend: Codable {
  let name: String
}

extension Friend: ResponseCodable {}
