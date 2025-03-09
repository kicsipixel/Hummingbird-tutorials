import FluentKit
import Foundation
import Hummingbird
import HummingbirdFluent

struct ParksController<Context: RequestContext> {

  let fluent: Fluent

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: self.create)
      .get(use: self.index)
      .get(":id", use: self.show)
      .put(":id", use: self.update)
      .delete(":id", use: self.delete)
  }

  // MARK: - create
  /// Creates new park entry
  @Sendable func create(_ request: Request, context: Context) async throws -> Park {
    let park = try await request.decode(as: Park.self, context: context)
    try await park.save(on: fluent.db())
    return park
  }

  // MARK: - index
  /// Returns with all parks in the database
  @Sendable func index(_ request: Request, context: Context) async throws -> [Park] {
    try await Park.query(on: self.fluent.db()).all()
  }

  // MARK: - show
  /// Returns with a park specified by its ID
  @Sendable func show(_ request: Request, context: Context) async throws -> Park? {
    let id = try context.parameters.require("id", as: UUID.self)

    guard let park = try await Park.find(id, on: fluent.db()) else {
      throw HTTPError(.notFound)
    }

    return park
  }

  // MARK: - update
  /// Updates the park specified by its ID
  @Sendable func update(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let id = try context.parameters.require("id", as: UUID.self)

    guard let park = try await Park.find(id, on: fluent.db()) else {
      throw HTTPError(.notFound)
    }

    let updatedPark = try await request.decode(as: Park.self, context: context)

    park.name = updatedPark.name
    park.coordinates.latitude = updatedPark.coordinates.latitude
    park.coordinates.longitude = updatedPark.coordinates.longitude

    try await park.save(on: fluent.db())

    return .ok
  }

  // MARK: - delete
  /// Removes the park specified by its ID from database
  @Sendable func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let id = try context.parameters.require("id", as: UUID.self)
    guard let park = try await Park.find(id, on: fluent.db()) else {
      throw HTTPError(.notFound)
    }

    try await park.delete(on: fluent.db())
    return .ok
  }
}
