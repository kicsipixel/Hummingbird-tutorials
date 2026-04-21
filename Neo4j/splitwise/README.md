# Splitwise

A demo application for [SwiftCypher](https://github.com/kicsipixel/SwiftCypher) — a lightweight Swift client for the Neo4j Query API. It implements a bill-splitting API built with [Hummingbird](https://github.com/hummingbird-project/hummingbird) and [Neo4j](https://neo4j.com).

## Preparation

Create a `.env` file:

```bash
# Local Neo4j
USERNAME=neo4j
PASSWORD=yourpassword
# Neo4j Aura (cloud) — set DEVELOPMENT=false to switch
DEVELOPMENT=false
AURA_DATABASE=<your-aura-instance-id>
AURA_USERNAME=neo4j
AURA_PASSWORD=<your-aura-password>
```

Start the server:

```shell
swift run App
```

---

## Routes

- __GET__: `/` - Hello
- __POST__: `/api/v1/friends` - Register a friend
- __GET__: `/api/v1/friends` - List all friends
- __GET__: `/api/v1/friends/:friendID` - Show a friend
- __PATCH__: `/api/v1/friends/:friendID` - Edit a friend
- __DELETE__: `/api/v1/friends/:friendID` - Delete a friend
- __POST__: `/api/v1/events` - Create an event
- __GET__: `/api/v1/events` - List all events
- __GET__: `/api/v1/events/:eventID` - Show an event
- __PATCH__: `/api/v1/events/:eventID` - Edit an event
- __DELETE__: `/api/v1/events/:eventID` - Delete an event
- __POST__: `/api/v1/activities` - Create an activity
- __GET__: `/api/v1/activities` - List all activities
- __GET__: `/api/v1/activities/:activityID` - Show an activity
- __PATCH__: `/api/v1/activities/:activityID` - Edit an activity
- __DELETE__: `/api/v1/activities/:activityID` - Delete an activity
- __GET__: `/api/v1/obligations/:eventID` - Show obligations for an event

---

### 👋 Hello

- __URL:__ `http://localhost:8080/`
- __Method:__ `GET`

```shell
curl -i http://localhost:8080/
HTTP/1.1 200 OK

Hello!
```

---

## 👥 Friends

---

### Register a friend

- __URL:__ `http://localhost:8080/api/v1/friends`
- __Method:__ `POST`

```shell
curl -X "POST" "http://localhost:8080/api/v1/friends" \
     -H 'Content-Type: application/json' \
     -d $'{"name": "Alice"}'
```

__Return value:__ `201 Created`

---

### List all friends

- __URL:__ `http://localhost:8080/api/v1/friends`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/friends"
```

__Return value:__ Array of friends

- `friend_id`: UUID
- `name`: name of the friend

```json
[
  {
    "friend_id": "8B1BEFA4-D6A0-4210-816E-958C8E332758",
    "name": "Bob"
  },
  {
    "friend_id": "0ADDDA24-533B-48C8-8E89-94D474B31BE9",
    "name": "Alice"
  }
]
```

---

### Show a friend

- __URL:__ `http://localhost:8080/api/v1/friends/:friendID`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/friends/8B1BEFA4-D6A0-4210-816E-958C8E332758"
```

__Return value:__

- `friend_id`: UUID
- `name`: name of the friend

```json
{
  "friend_id": "8B1BEFA4-D6A0-4210-816E-958C8E332758",
  "name": "Bob"
}
```

---

### Edit a friend

- __URL:__ `http://localhost:8080/api/v1/friends/:friendID`
- __Method:__ `PATCH`

```shell
curl -X "PATCH" "http://localhost:8080/api/v1/friends/8B1BEFA4-D6A0-4210-816E-958C8E332758" \
     -H 'Content-Type: application/json' \
     -d $'{"name": "Robert"}'
```

__Return value:__ Updated friend object

---

### Delete a friend

- __URL:__ `http://localhost:8080/api/v1/friends/:friendID`
- __Method:__ `DELETE`

```shell
curl -X "DELETE" "http://localhost:8080/api/v1/friends/8B1BEFA4-D6A0-4210-816E-958C8E332758"
```

__Return value:__ `204 No Content`

---

## 📅 Events

---

### Create an event

- __URL:__ `http://localhost:8080/api/v1/events`
- __Method:__ `POST`

```shell
curl -X "POST" "http://localhost:8080/api/v1/events" \
     -H 'Content-Type: application/json' \
     -d $'{
  "name": "Skiing in Tirol",
  "start_date": "2026-02-01",
  "end_date": "2026-02-03",
  "description": "Weekend trip to the mountains"
}'
```

__Return value:__ `201 Created`

---

### List all events

- __URL:__ `http://localhost:8080/api/v1/events`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/events"
```

__Return value:__ Array of events

- `event_id`: UUID
- `name`: name of the event
- `start_date`: ISO 8601 date string
- `end_date`: ISO 8601 date string
- `description`: description of the event

```json
[
  {
    "event_id": "0ADA5DAA-269E-4732-AF7C-12037AF72121",
    "name": "Skiing in Tirol",
    "start_date": "2026-02-01",
    "end_date": "2026-02-03",
    "description": "Weekend trip to the mountains"
  }
]
```

---

### Show an event

- __URL:__ `http://localhost:8080/api/v1/events/:eventID`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/events/0ADA5DAA-269E-4732-AF7C-12037AF72121"
```

__Return value:__ Single event object

---

### Edit an event

- __URL:__ `http://localhost:8080/api/v1/events/:eventID`
- __Method:__ `PATCH`

```shell
curl -X "PATCH" "http://localhost:8080/api/v1/events/0ADA5DAA-269E-4732-AF7C-12037AF72121" \
     -H 'Content-Type: application/json' \
     -d $'{"name": "Skiing in Austria"}'
```

__Return value:__ Updated event object

---

### Delete an event

- __URL:__ `http://localhost:8080/api/v1/events/:eventID`
- __Method:__ `DELETE`

```shell
curl -X "DELETE" "http://localhost:8080/api/v1/events/0ADA5DAA-269E-4732-AF7C-12037AF72121"
```

__Return value:__ `204 No Content`

---

## 🏃 Activities

---

### Create an activity

- __URL:__ `http://localhost:8080/api/v1/activities`
- __Method:__ `POST`

```shell
curl -X "POST" "http://localhost:8080/api/v1/activities" \
     -H 'Content-Type: application/json' \
     -d $'{
  "name": "Coffee",
  "date": "2026-02-02",
  "amount": 15,
  "currency": "EUR",
  "event_id": "0ADA5DAA-269E-4732-AF7C-12037AF72121",
  "payer": "Bob",
  "participants": ["Alice", "Charles"]
}'
```

__Return value:__ `201 Created`

---

### List all activities

- __URL:__ `http://localhost:8080/api/v1/activities`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/activities"
```

__Return value:__ Array of activities

- `activity_id`: UUID
- `name`: description of the activity
- `date`: ISO 8601 date string
- `amount`: total amount paid
- `currency`: currency code
- `event_id`: UUID of the parent event
- `payer`: name of the friend who paid
- `participants`: names of friends who share the cost (excluding the payer)

```json
[
  {
    "activity_id": "BB424222-8173-4209-A5C8-CC305B5371EF",
    "name": "Coffee",
    "date": "2026-02-02",
    "amount": 15,
    "currency": "EUR",
    "event_id": "0ADA5DAA-269E-4732-AF7C-12037AF72121",
    "payer": "Bob",
    "participants": ["Alice", "Charles"]
  }
]
```

---

### Show an activity

- __URL:__ `http://localhost:8080/api/v1/activities/:activityID`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/activities/BB424222-8173-4209-A5C8-CC305B5371EF"
```

__Return value:__ Single activity object

---

### Edit an activity

- __URL:__ `http://localhost:8080/api/v1/activities/:activityID`
- __Method:__ `PATCH`

```shell
curl -X "PATCH" "http://localhost:8080/api/v1/activities/BB424222-8173-4209-A5C8-CC305B5371EF" \
     -H 'Content-Type: application/json' \
     -d $'{"name": "Tea", "amount": 5.0}'
```

__Return value:__ Updated activity object

---

### Delete an activity

- __URL:__ `http://localhost:8080/api/v1/activities/:activityID`
- __Method:__ `DELETE`

```shell
curl -X "DELETE" "http://localhost:8080/api/v1/activities/BB424222-8173-4209-A5C8-CC305B5371EF"
```

__Return value:__ `204 No Content`

---

## 💸 Obligations

---

### Show obligations for an event

Returns each participant's consolidated debt to the payer for all activities in the event. Each person's share is their equal portion of each activity's total amount.

- __URL:__ `http://localhost:8080/api/v1/obligations/:eventID`
- __Method:__ `GET`

```shell
curl "http://localhost:8080/api/v1/obligations/0ADA5DAA-269E-4732-AF7C-12037AF72121"
```

__Return value:__ Array of obligations

- `event`: name of the event
- `payer`: name of the friend who paid
- `participant`: name of the friend who owes
- `owes`: total amount owed (sum across all activities)
- `currency`: currency code

```json
[
  {
    "event": "Skiing in Tirol",
    "payer": "Bob",
    "participant": "Alice",
    "owes": 15,
    "currency": "EUR"
  },
  {
    "event": "Skiing in Tirol",
    "payer": "Bob",
    "participant": "Charles",
    "owes": 15,
    "currency": "EUR"
  }
]
```
