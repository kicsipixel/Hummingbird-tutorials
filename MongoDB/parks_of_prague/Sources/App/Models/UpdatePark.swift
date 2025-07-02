import Hummingbird

struct UpdatePark: Codable {
  let name: String?
  let coordinates: Coordinates?
  
  struct Coordinates: ResponseCodable {
    let latitude: Double?
    let longitude: Double?
  }
}
