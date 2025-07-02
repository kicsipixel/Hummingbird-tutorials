import Hummingbird
import MongoKitten

struct Park: ResponseCodable {
  static let collection = "parks"

  let _id: ObjectId?
  var name: String
  var coordinates: Coordinates
  
  struct Coordinates: ResponseCodable {
    let latitude: Double
    let longitude: Double
  }
}
