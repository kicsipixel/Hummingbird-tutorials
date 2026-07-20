import Hummingbird
import MultipartKit
import StructuredFieldValues

/// A file decoded from a multipart form part, based on the Hummingbird multipart-form example
struct File: MultipartPartConvertible, Decodable, Sendable {
    let data: ByteBuffer
    let filename: String
    let contentType: String

    var multipart: MultipartPart? { nil }

    init?(multipart: MultipartPart) {
        self.data = multipart.body
        guard let contentType = multipart.headers["content-type"].first else {
            return nil
        }
        guard let contentDispositionHeader = multipart.headers["content-disposition"].first else {
            return nil
        }
        guard
            let contentDisposition = try? StructuredFieldValueDecoder().decode(
                MultipartContentDisposition.self,
                from: Array(contentDispositionHeader.utf8)
            )
        else {
            return nil
        }
        guard let filename = contentDisposition.parameters.filename else {
            return nil
        }
        self.filename = filename
        self.contentType = contentType
    }
}

/// The `content-disposition` header of a multipart part, e.g. `form-data; name="file"; filename="photo.jpg"`
struct MultipartContentDisposition: StructuredFieldValue {
    struct Parameters: StructuredFieldValue {
        static let structuredFieldType: StructuredFieldType = .dictionary

        var name: String
        var filename: String?
    }

    static let structuredFieldType: StructuredFieldType = .item

    var item: String
    var parameters: Parameters
}
