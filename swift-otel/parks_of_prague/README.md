# OpenTelemetry with Hummingbird 2

Example app using [OracleNIO](https://github.com/lovetodream/oracle-nio/tree/main) to connect to Oracle database and OpenTelemetry by [swift-otel](https://github.com/swift-otel/swift-otel).

Logging, Metric and Tracing were implemented in: `/api/v1/parks` with `GET` method.

Grafana works on `http://localhost:3000` after starting all components with:
```
$ docker compose up
```
OR
```
$ docker compose --profile otel up
$ swift run App
```