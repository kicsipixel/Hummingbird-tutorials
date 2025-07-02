import Hummingbird
import Logging
import MongoKitten

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable. 
/// Any variables added here also have to be added to `App` in App.swift and 
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = Environment()
    let logger = {
        var logger = Logger(label: "parks_of_prague")
        logger.logLevel = 
            arguments.logLevel ??
            environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ??
            .info
        return logger
    }()
    
    let router = try buildRouter()
    
    // Connect to database
    let mongo = try await MongoDatabase.connect(to: "mongodb://localhost:27017/parks_of_prague")
    
    // Controller
    ParksController(mongoDb: mongo, logger: logger).addRoutes(to: router.group("api/v1/parks"))
    
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "parks_of_prague"
        ),
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
    }
    
    // Add default endpoint
    router.get("/") { _,_ in
        return "Hello!"
    }
    
    // Add /health route
        router.get("/health") { _,_ -> HTTPResponse.Status in
            .ok
        }
    return router
}
