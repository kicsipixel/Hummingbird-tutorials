import Foundation
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
      .get(":friendID", use: show)
      .patch(":friendID", use: edit)
      .delete(":friendID", use: delete)
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
    let friend = try await request.decode(as: Friend.Create.self, context: context)

    /// `CREATE (alice:FRIEND {friend_id: $friendID, name: $name})`
    let queryRequest = QueryRequest(
      statement: "CREATE (n:FRIEND {friend_id: $friendID, name: $name})",
      parameters: [
        "friendID": .string(UUID().uuidString),
        "name": .string(friend.name),
      ]
    )
    _ = try await client.runQuery(request: queryRequest)

    return .created
  }

  // MARK: - index
  /// Returns with all nodes with `FRIEND` label in the database
  /// `curl "http://localhost:8080/api/v1/friends"`
  @Sendable
  func index(_ request: Request, context: Context) async throws -> [Friend] {
    var friends = [Friend]()

    /// `MATCH (n:FRIEND) RETURN n`
    let queryRequest = QueryRequest(statement: "MATCH (n:FRIEND) RETURN n")
    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let friendIdString = node.properties["friend_id"]?.stringValue,
        let friendID = UUID(uuidString: friendIdString),
        let name = node.properties["name"]?.stringValue
      {
        friends.append(Friend(friendID: friendID, name: name))
      }
    }

    return friends
  }

  // MARK: - show
  /// Returns with a node with single `FRIEND` node
  /// `curl "http://localhost:8080/api/v1/friends/2DB325DC-6884-40EB-8ECB-8695641746DD"`
  @Sendable
  func show(_ request: Request, context: Context) async throws -> Friend {
    let friendID = try context.parameters.require("friendID", as: String.self)

    /// `MATCH (n:FRIEND {friend_id: '2DB325DC-6884-40EB-8ECB-8695641746DD'}) RETURN n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {friend_id: $friendID}) RETURN n",
      parameters: ["friendID": .string(friendID)]
    )

    let response = try await client.runQuery(request: queryRequest)
    for row in response.rows {
      if let node = row["n"]?.nodeValue,
        let friendIdString = node.properties["friend_id"]?.stringValue,
        let friendID = UUID(uuidString: friendIdString),
        let name = node.properties["name"]?.stringValue
      {
        return Friend(friendID: friendID, name: name)
      }
    }
    throw HTTPError(.notFound, message: "The friend with id:\(friendID) was not found")
  }

  // MARK: - edit
  /// Edits node
  /// `curl -X "PATCH" "http://localhost:8080/api/v1/friends/2DB325DC-6884-40EB-8ECB-8695641746DD" \
  ///     -H 'Content-Type: application/json' \
  ///     -d $'{
  ///  "name": "Emma"
  ///  }'`
  @Sendable
  func edit(_ request: Request, context: Context) async throws -> Friend {
    let friendID = try context.parameters.require("friendID", as: String.self)
    let newFriend = try await request.decode(as: Friend.Create.self, context: context)

    /// `MATCH (n:FRIEND {friend_id: '2DB325DC-6884-40EB-8ECB-8695641746DD'}) SET n.name = 'Emma';`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {friend_id: $friendID}) SET n.name = $newName",
      parameters: [
        "friendID": .string(friendID),
        "newName": .string(newFriend.name),
      ]
    )

    let response = try await client.runQuery(request: queryRequest)
    guard response.counters?.propertiesSet ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "The friend with id:\(friendID) was not found")
    }
    guard let friendUUID = UUID(uuidString: friendID) else {
      throw HTTPError(.badRequest, message: "Invalid friend_id format")
    }
    return Friend(friendID: friendUUID, name: newFriend.name)
  }

  // MARK: - delete
  /// Deletes a node
  /// `curl -X "DELETE" "http://localhost:8080/api/v1/friends/2DB325DC-6884-40EB-8ECB-8695641746DD"`
  @Sendable
  func delete(_ request: Request, context: Context) async throws -> HTTPResponse.Status {
    let friendID = try context.parameters.require("friendID", as: String.self)

    /// `MATCH (n:FRIEND {friend_id: '2DB325DC-6884-40EB-8ECB-8695641746DD'}) DETACH DELETE n;`
    let queryRequest = QueryRequest(
      statement: "MATCH (n:FRIEND {friend_id: $friendID}) DETACH DELETE n",
      parameters: ["friendID": .string(friendID)]
    )
    let response = try await client.runQuery(request: queryRequest)

    guard response.counters?.nodesDeleted ?? 0 > 0 else {
      throw HTTPError(.notFound, message: "The friend with id:\(friendID) was not found")
    }
    return .noContent
  }
}
