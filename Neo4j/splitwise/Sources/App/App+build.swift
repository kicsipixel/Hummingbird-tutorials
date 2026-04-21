import Configuration
import Hummingbird
import Logging
import SwiftCypher

// Request context used by application
typealias AppRequestContext = BasicRequestContext

///  Build application
/// - Parameter reader: configuration reader
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
  let logger = {
    var logger = Logger(label: "splitwise")
    logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
    return logger
  }()

  let router = try buildRouter()

  // MARK: - Database
  let isDevelopmentMode = reader.bool(forKey: "DEVELOPMENT", default: true)
  let client: SwiftCypherClient
  if isDevelopmentMode {
    // Neo4j local database
    let localUsername = reader.string(forKey: "USERNAME") ?? "neo4j"
    let localPassword = reader.string(forKey: "PASSWORD") ?? "password"
    client = try await SwiftCypherClient.connect(service: .localhost(database: "splitwise"), username: localUsername, password: localPassword)
  }
  else {
    // Neo4j remote database
    let remoteUsername = reader.string(forKey: "AURA_USERNAME") ?? "neo4j"
    let remotePassword = reader.string(forKey: "AURA_PASSWORD") ?? "password"
    let remoteHost = reader.string(forKey: "AURA_DATABASE") ?? "localhost"
    client = try await SwiftCypherClient.connect(service: .aura(database: remoteHost), username: remoteUsername, password: remotePassword)
  }

  // MARK: - Controllers
  FriendsController(client: client, logger: logger).addRoutes(to: router.group("api/v1/friends"))
  EventsController(client: client, logger: logger).addRoutes(to: router.group("api/v1/events"))
  ActivitiesController(client: client, logger: logger).addRoutes(to: router.group("api/v1/activities"))
  ObligationsController(client: client, logger: logger).addRoutes(to: router.group("api/v1/obligations"))

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
  }
  // Add default endpoint
  router.get("/") { _, _ in
    return "Hello!"
  }
  return router
}
