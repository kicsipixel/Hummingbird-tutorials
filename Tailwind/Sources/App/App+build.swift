import Configuration
import Foundation
import Hummingbird
import Logging
import Mustache
import SwiftKaze

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "Tailwind")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    let router = try buildRouter()

    // Mustache
    let library = try await MustacheLibrary(directory: Bundle.module.bundleURL.path)
    assert(library.getTemplate(named: "base") != nil)

    // SwiftKaze
    let kaze = SwiftKaze()
    guard let inputURL = Bundle.module.url(forResource: "app", withExtension: "css") else {
        throw HTTPError(.notFound, message: "File not found.")
    }
    let outputURL = URL(fileURLWithPath: "public/styles/app.css")

    try await kaze.run(
        input: inputURL,
        output: outputURL,
        in: Bundle.module.bundleURL
    )

    // Controllers
    WebsitesController(mustacheLibrary: library).addRoutes(to: router)

    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter() throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // serving static files
        FileMiddleware()
    }

    return router
}
