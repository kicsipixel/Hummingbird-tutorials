import Hummingbird
import Logging
import SwiftCypher

struct FriendsController<Context: RequestContext> {
  let client: SwiftCypherClient
  let logger: Logger

  func addRoutes(to group: RouterGroup<Context>) {
    group
      .post(use: create)
      .get(use: index)
      .get("/:friend", use: show)
      .patch("/:friend", use: edit)
      .delete("/:friend", use: delete)
  }

  // MARK: - create
  /// Creates a node with label
  /// `curl -X "POST" "http://localhost:8080/api/v1/friends" \
  ///   -H 'Content-Type: text/plain; charset=utf-8' \
  ///    -d $'{
  ///  "name": "Alice"
  /// }'`
  @Sendable
  func create(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let friend = try await request.decode(as: Friend.self, context: context)

    /// `CREATE (alice:FRIEND {name: 'Alice'})`
    let queryRequest = QueryRequest(statement: "CREATE (n:FRIEND {name: $name})", parameters: ["name": .string("\(friend.name)")])
    _ = try await client.runQuery(request: queryRequest)

    return .created
  }

  // MARK: - index
  /// Returns with all nodes with `FRIEND` label in the database
  /// `curl "http://localhost:8080/api/v1/friends"`
  @Sendable
  func index(_ request: Request, context: Context) async throws -> [Friend] {
    var friends = [Friend]()

    /// `MATCH (n:FRIEND) RETURN n.name`
    let queryRequest = QueryRequest(statement: "MATCH (n:FRIEND) RETURN n")
    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let name = node.properties["name"]?.stringValue
      {
        friends.append(Friend(name: name))
      }
    }

    return friends
  }

  // MARK: - show
  /// Returns with a node with single `FRIEND` node
  /// `curl "http://localhost:8080/api/v1/friends/Alice"`
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Friend {
    let friend = try context.parameters.require("friend", as: String.self)

    /// `MATCH (n:FRIEND {name: 'Alice'}) RETURN n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {name: $name}) RETURN n",
      parameters: [
        "name": .string(friend)
      ]
    )

    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let node = row["n"]?.nodeValue, let name = node.properties["name"]?.stringValue {
        return Friend(name: name)
      }
    }
    throw HTTPError(.notFound, message: "The friend with name \(friend) was not found")
  }

  // MARK: - edit
  /// Edits node
  /// `curl -X "PATCH" "http://localhost:8080/api/v1/friends/Alice" \
  ///     -H 'Content-Type: application/json' \
  ///     -d $'{
  ///  "name": "Emma"
  ///  }'`
  @Sendable
  func edit(_ request: Request, context: Context) async throws -> Friend {
    let originalFriend = try context.parameters.require("friend", as: String.self)
    let newFriend = try await request.decode(as: Friend.self, context: context)

    /// `MATCH (n:FRIEND {name: 'Alice'}) SET n.name = 'Emma';`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {name: $oldName}) SET n.name = $newName",
      parameters: [
        "oldName": .string(originalFriend),
        "newName": .string(newFriend.name),
      ]
    )

    let response = try await client.runQuery(request: queryRequest)
    guard response.counters?.propertiesSet ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "The friend with name \(originalFriend) was not found")
    }
    return Friend(name: newFriend.name)
  }

  // MARK: - delete
  /// Deletes a node
  /// `curl -X "DELETE" "http://localhost:8080/api/v1/friends/Alice"`
  @Sendable
  func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let friend = try context.parameters.require("friend", as: String.self)

    /// MATCH (n:FRIEND {name: 'Alice'}) DETACH DELETE n;
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {name: $name}) DETACH DELETE n",
      parameters: ["name": .string(friend)]
    )
    let response = try await client.runQuery(request: queryRequest)

    // Check if the database has deleted the node
    guard response.counters?.nodesDeleted ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "The friend with name \(friend) was not found")
    }
    return .noContent
  }
}
