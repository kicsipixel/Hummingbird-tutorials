import Foundation
import Hummingbird
import Logging
import OCIKit

struct ObjectsController<Context: RequestContext> {
    let objectStorageClient: ObjectStorageClient
    let logger: Logger

    func addRoutes(to group: RouterGroup<Context>) {
        group
            .post("/list", use: listObjects)
            .post(use: uploadObject)
    }

    /// Lists all objects in the bucket, if the PAR settings allow it
    @Sendable
    func listObjects(_ request: Request, context: Context) async throws -> [String] {
        let basket = try await request.decode(as: Basket.self, context: context)

        guard let parURL = URL(string: basket.parURL) else {
            logger.error("The PAR URL is not valid or not properly formatted.")
            throw HTTPError(.badRequest)
        }

        let listOfObjects: ListObjects = try await objectStorageClient.listObjects(parURL: parURL)

        return listOfObjects.objects.map(\.name)
    }

    /// Uploads an object to the bucket defined by the PAR.
    ///
    /// The object name and the PAR URL are passed as query parameters, the request body is the raw file content:
    /// ```
    /// curl -X "POST" "http://localhost:8080/api/v1/objects" \
    ///      --url-query "objectName=photo.jpg" \
    ///      --url-query "parURL=https://objectstorage.<region>.oraclecloud.com/p/<token>/n/<namespace>/b/<bucket>/o/" \
    ///      -H 'Content-Type: application/octet-stream' \
    ///      --data-binary @photo.jpg
    /// ```
    @Sendable
    func uploadObject(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
        guard let parURLString = request.uri.queryParameters.get("parURL"),
            let parURL = URL(string: parURLString)
        else {
            logger.error("The PAR URL is not valid or not properly formatted.")
            throw HTTPError(.badRequest)
        }

        guard let objectName = request.uri.queryParameters.get("objectName") else {
            logger.error("The object name is missing.")
            throw HTTPError(.badRequest)
        }

        let putObjectBody = try await request.body.collect(upTo: .max)

        do {
            try await objectStorageClient.putObject(parURL: parURL, objectName: objectName, putObjectBody: Data(buffer: putObjectBody))
        } catch {
            logger.error("[uploadObject] Error during upload: \(error)")
            throw HTTPError(.internalServerError)
        }
        return .created
    }
}
