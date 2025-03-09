import FluentPostgresDriver
import Hummingbird
import HummingbirdFluent
import Logging

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
public func buildApplication(_ arguments: some AppArguments) async throws
  -> some ApplicationProtocol
{
  let environment = Environment()
  let logger = {
    var logger = Logger(label: "parks_of_prague")
    logger.logLevel =
      arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) }
      ?? .info
    return logger
  }()

  let fluent = Fluent(logger: logger)
  let router = buildRouter(fluent: fluent)

  // Reading .env file
  let env = try await Environment.dotEnv()

  // PostgreSQL database configuration
  let postgreSQLConfig = SQLPostgresConfiguration(
    hostname: "localhost",
    port: env.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
    username: env.get("DATABASE_USERNAME") ?? "username",
    password: env.get("DATABASE_PASSWORD") ?? "password",
    database: env.get("DATABASE_NAME") ?? "hb-db",
    tls: .prefer(try .init(configuration: .clientDefault)))

  fluent.databases.use(.postgres(configuration: postgreSQLConfig, sqlLogLevel: .warning), as: .psql)
  await fluent.migrations.add(CreateParkTableMigration())
  try await fluent.migrate()

  var app = Application(
    router: router,
    configuration: .init(
      address: .hostname(arguments.hostname, port: arguments.port),
      serverName: "parks_of_prague"
    ),
    logger: logger
  )
  app.addServices(fluent)
  return app
}

/// Build router
func buildRouter(fluent: Fluent) -> Router<AppRequestContext> {
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

  // Add /health route
  router.get("/health") { _, _ -> HTTPResponse.Status in
    .ok
  }

  ParksController(fluent: fluent).addRoutes(to: router.group("api/v1/parks"))

  return router
}
