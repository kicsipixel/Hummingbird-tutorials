import Foundation
import Hummingbird
import Logging
import MultipartKit
import Mustache
import OCIKit

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct WebPagesController<Context: RequestContext> {

    let objectStorageClient: ObjectStorageClient
    let logger: Logger
    let mustacheLibrary: MustacheLibrary

    func addRoutes(to group: RouterGroup<Context>) {
        group
            .get("/", use: indexHandler)
            .post("/", use: indexPostHandler)
    }

    /// Renders the index page. `uploaded` and `error` query parameters, set by the
    /// post-upload redirect, are passed to the template as feedback messages.
    /// The PAR URL of the last upload is remembered in a cookie, so the field comes pre-filled.
    @Sendable
    func indexHandler(_ request: Request, context: Context) async throws -> HTML {
        let indexContext = IndexContext(
            uploaded: request.uri.queryParameters.get("uploaded"),
            error: request.uri.queryParameters.get("error") != nil,
            parURL: request.cookies["parURL"]?.value
        )

        guard let html = self.mustacheLibrary.render(indexContext, withTemplate: "index") else {
            throw HTTPError(.internalServerError, message: "Failed to render template.")
        }

        return HTML(html: html)
    }

    /// Handles the upload form submission, then redirects back to the index page (Post-Redirect-Get)
    @Sendable
    func indexPostHandler(_ request: Request, context: Context) async throws -> Response {
        guard let contentType = request.headers[.contentType],
            let mediaType = MediaType(from: contentType),
            let parameter = mediaType.parameter,
            parameter.name == "boundary"
        else {
            throw HTTPError(.unsupportedMediaType)
        }

        let buffer = try await request.body.collect(upTo: .max)
        let basket = try FormDataDecoder().decode(Basket.self, from: buffer, boundary: parameter.value)

        guard let parURL = URL(string: basket.parURL), let file = basket.file else {
            logger.error("The PAR URL is not valid or the file is missing.")
            return redirect(to: "/?error=true", remembering: basket.parURL)
        }

        do {
            try await objectStorageClient.putObject(
                parURL: parURL,
                objectName: file.filename,
                putObjectBody: Data(buffer: file.data)
            )
        } catch {
            logger.error("[indexPostHandler] Error during upload: \(error)")
            return redirect(to: "/?error=true", remembering: basket.parURL)
        }

        let filename = file.filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "file"
        return redirect(to: "/?uploaded=\(filename)", remembering: basket.parURL)
    }

    /// Redirects back to the index page, remembering the PAR URL in a cookie for 30 days
    private func redirect(to location: String, remembering parURL: String) -> Response {
        var response = Response.redirect(to: location, type: .found)
        response.setCookie(Cookie(name: "parURL", value: parURL, maxAge: 60 * 60 * 24 * 30, httpOnly: true))
        return response
    }
}
