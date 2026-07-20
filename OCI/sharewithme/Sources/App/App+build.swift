import Configuration
import Foundation
import Hummingbird
import Logging
import Mustache
import OCIKit

/// App version and info
enum AppInfo {
    static let version = "0.2.5"
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "sharewithme")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    let router = try buildRouter(logger: logger)

    // OCIKit setup
    let region = Region.from(regionId: reader.string(forKey: "oci.region", default: "eu-frankfurt-1"))
    let signer = try InstancePrincipalSigner()
    let objectStorageClient = try ObjectStorageClient(region: region, signer: signer)

    // Mustache
    let mustacheLibrary = try await MustacheLibrary(directory: Bundle.module.bundleURL.path)
    assert(mustacheLibrary.getTemplate(named: "base") != nil)

    // Controllers
    ObjectsController(objectStorageClient: objectStorageClient, logger: logger).addRoutes(to: router.group("api/v1/objects"))
    WebPagesController(objectStorageClient: objectStorageClient, logger: logger, mustacheLibrary: mustacheLibrary).addRoutes(to: router.group("/"))

    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(logger: Logger) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        FileMiddleware()
    }

    // Add health endpoint
    router.get("/health") { _, _ -> HTTPResponse.Status in
        logger.info("[sharewithme] - The server is up and running")
        return .ok
    }

    // Add version endpoint
    router.get("/version") { _, _ -> String in
        logger.info("[sharewithme] - The app version is: \(AppInfo.version).")
        return AppInfo.version
    }

    return router
}
