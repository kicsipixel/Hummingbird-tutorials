import Hummingbird
import Logging
import MongoKitten

struct ParksController<Context: RequestContext> {
  let mongoDb: MongoDatabase
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: create)
      .get(use: index)
      .get(":id", use: show)
      .patch(":id", use: update)
      .delete(":id", use: delete)
  }

  // MARK: - create
  /// Creates a new park with `name` and `coordinates`
  @Sendable
  func create(_ request: Request, context: Context) async throws -> Park {
    let body = try await request.decode(as: Park.self, context: context)

    let park = Park(
      _id: ObjectId(),
      name: body.name,
      coordinates: Park.Coordinates(
        latitude: body.coordinates.latitude,
        longitude: body.coordinates.longitude
      )
    )

    try await mongoDb["parks"].insertEncoded(park)
    return park
  }

  // MARK: - index
  /// List all parks in the database
  func index(_ request: Request, context: Context) async throws -> [Park] {
    try await mongoDb["parks"].find().decode(Park.self).drain()
  }

  // MARK: - show
  /// Returns a single park with id
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Park? {
    let id: ObjectId = try context.parameters.require("id", as: ObjectId.self)
    guard
      let park = try await mongoDb["parks"].findOne("_id" == id, as: Park.self)
    else {
      throw HTTPError(.notFound, message: "The park has not been found.")
    }
    return park
  }

  // MARK: - update
  /// Updates a single park with id
  @Sendable
  func update(_ request: Request, context: Context) async throws -> Park? {
    let id: ObjectId = try context.parameters.require("id", as: ObjectId.self)
    let park = try await request.decode(as: UpdatePark.self, context: context)
    var changedFields = Document()

    changedFields["name"] = park.name

    if let coordinates = park.coordinates {
      if let latitude = coordinates.latitude {
        changedFields["coordinates.latitude"] = latitude
      }
      if let longitude = coordinates.longitude {
        changedFields["coordinates.longitude"] = longitude
      }
    }

    return try await mongoDb["parks"].findOneAndUpdate(
      where: "_id" == id,
      to: [
        "$set": changedFields
      ],
      returnValue: .modified
    ).decode(Park.self)
  }

  // MARK: - delete
  /// Deletes park with id
  @Sendable
  func delete(_: Request, context: Context) async throws -> Park? {
    let id: ObjectId = try context.parameters.require("id", as: ObjectId.self)

    guard
      let park = try await mongoDb["parks"].findOneAndDelete(where: "_id" == id)
        .decode(Park.self)
    else {
      throw HTTPError(.notFound, message: "The park has not been found.")
    }

    return park
  }
}
