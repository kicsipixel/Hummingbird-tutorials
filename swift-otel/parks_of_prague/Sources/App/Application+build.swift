import Foundation
import Hummingbird
import Logging
import LoggingLoki
import Metrics
import NIOCore
import OTLPGRPC
import OTel
import OracleNIO
import Tracing

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
  var hostname: String { get }
  var port: Int { get }
  var logLevel: Logger.Level? { get }
}

struct AppRequestContext: RequestContext {
  var coreContext: CoreRequestContextStorage
  let channel: Channel

  init(source: Source) {
    self.coreContext = .init(source: source)
    self.channel = source.channel
  }
}

extension AppRequestContext: RemoteAddressRequestContext {
  var remoteAddress: NIOCore.SocketAddress? { self.channel.remoteAddress }
}
///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {

  // MARK: - Logging
  let processor = LokiLogProcessor(configuration: LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100"))
  LoggingSystem.bootstrap { label in
    LokiLogHandler(label: label, processor: processor)
  }

  let logger = Logger(label: "parks_of_prague_api")

  // MARK: - Metrics
  let environment = OTelEnvironment.detected()
  let resourceDetection = OTelResourceDetection(detectors: [
    OTelProcessResourceDetector(),
    OTelEnvironmentResourceDetector(environment: environment),
    .manual(OTelResource(attributes: ["service.name": "hummingbird_server"])),
  ])
  let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

  // Bootstrap the metrics backend to export metrics periodically in OTLP/gRPC.
  let registry = OTelMetricRegistry()
  let metricsExporter = try OTLPGRPCMetricExporter(configuration: .init(environment: environment))
  let metrics = OTelPeriodicExportingMetricsReader(
    resource: resource,
    producer: registry,
    exporter: metricsExporter,
    configuration: .init(
      environment: environment,
      exportInterval: .seconds(5)
    )
  )
  MetricsSystem.bootstrap(OTLPMetricsFactory(registry: registry))

  // MARK: - Tracing
  // Bootstrap the tracing backend to export traces periodically in OTLP/gRPC.
  let exporter = try OTLPGRPCSpanExporter(configuration: .init(environment: environment))
  let tracerProcessor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: environment))
  let tracer = OTelTracer(
    idGenerator: OTelRandomIDGenerator(),
    sampler: OTelConstantSampler(isOn: true),
    propagator: OTelW3CPropagator(),
    processor: tracerProcessor,
    environment: environment,
    resource: resource
  )
  InstrumentationSystem.bootstrap(tracer)

  let router = buildRouter()
  let env = try await Environment.dotEnv()

  /// Database configuration
  /// Use `docker  run --name oracle23ai -p 1521:1521 -e ORACLE_PWD=OracleIsAwesome container-registry.oracle.com/database/free:latest-lite`
  let config = OracleConnection.Configuration(
    host: env.get("DATABASE_HOST") ?? "127.0.0.1",
    service: .serviceName(env.get("DATABASE_SERVICE_NAME") ?? "FREE"),
    username: env.get("DATABASE_USERNAME") ?? "SYSTEM",
    password: env.get("DATABASE_PASSWORD") ?? "OracleIsAwesome"
  )

  /// Remote Database configuration
  /// Use Connection string: `(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=gdb965aee735fa8_szabolcstothdb_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))`
  //  let resourcePath = Bundle.module.bundleURL.path
  //  let config = try OracleConnection.Configuration(
  //     host: env.get("REMOTE_DATABASE_HOST") ?? "adb.eu-frankfurt-1.oraclecloud.com",
  //     port: env.get("REMOTE_DATABASE_PORT").flatMap(Int.init(_:)) ?? 1522,
  //     service: .serviceName(
  //       env.get("REMOTE_DATABASE_SERVICE_NAME") ?? "service_low.adb.oraclecloud.com"),
  //     username: env.get("REMOTE_DATABASE_USERNAME") ?? "ADMIN",
  //     password: env.get("REMOTE_DATABASE_PASSWORD") ?? "Secr3t",
  //     tls: .require(
  //       .init(
  //         configuration: .makeOracleWalletConfiguration(
  //           wallet: "\(resourcePath)",
  //           walletPassword: env.get("REMOTE_DATABASE_WALLET_PASSWORD") ?? "$ecr3t"))))

  let connection = try await OracleConnection.connect(configuration: config, id: 1, logger: logger)

  /// Create the table in the database using the new `IF NOT EXISTS` keyword
  do {
    try await connection.execute(
      """
          CREATE TABLE IF NOT EXISTS parks (
            id RAW (16) DEFAULT SYS_GUID () PRIMARY KEY,
            coordinates SDO_GEOMETRY,
            details JSON
      )
      """,
      logger: logger
    )
  }
  catch {
    logger.error("Failed to create table", metadata: ["error message": "\(String(reflecting: error))"])
  }

  /// Close your connection once done
  try await connection.close()

  let client = OracleClient(configuration: config, backgroundLogger: logger)

  /// Controller
  ParksController(client: client, logger: logger).addRoutes(to: router.group("api/v1/parks"))

  var app = Application(
    router: router,
    configuration: .init(
      address: .hostname(arguments.hostname, port: arguments.port),
      serverName: "otel"
    ),
    logger: logger
  )

  app.addServices(client, processor, metrics, tracer)
  return app
}

/// Build router
func buildRouter() -> Router<AppRequestContext> {
  let router = Router(context: AppRequestContext.self)
  // Add middleware
  router.addMiddleware {
    // Logging middleware
    LogRequestsMiddleware(.info)
    // Metrics middlewate
    MetricsMiddleware()
    // Tracing middleware
    TracingMiddleware()
  }
  // Add default endpoint
  router.get("/") { _, _ in
    return "Hello!"
  }

  // Add /health route
  router.get("/health") { _, _ -> HTTPResponse.Status in
    .ok
  }

  return router
}
