import Hummingbird

/// The PAR URL of the bucket, with an optional file when submitted from the upload form
struct Basket: Decodable {
    let parURL: String
    let file: File?
}
