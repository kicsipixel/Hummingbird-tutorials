import Foundation
import Hummingbird
import Mustache

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct WebsitesController {

    let mustacheLibrary: MustacheLibrary

    func addRoutes(to router: Router<some RequestContext>) {
        router.get("/", use: self.indexHandler)
    }

    @Sendable func indexHandler(request: Request, context: some RequestContext) async throws -> HTML {
        guard let html = self.mustacheLibrary.render((), withTemplate: "index") else {
            throw HTTPError(.internalServerError, message: "Failed to render template.")
        }

        return HTML(html: html)
    }
}
