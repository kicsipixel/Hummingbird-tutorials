# Share files using OCI Object Storage

Example app using [OCIKit](https://github.com/iliasaz/oci-swift-sdk) to connect to Oracle Cloud Infrastructure (OCI) Object Storage. The app authenticates with an Instance Principal signer and works with buckets through Pre-Authenticated Requests (PAR), so the user can list the objects in the bucket and upload new ones.

Live at [sharewithme.app](https://sharewithme.app).

This project accompanies the "From Zero to MicroSaaS" article series. Each article part has a matching git tag with the complete, working state of the code at that point — `sharewithme-part-1`, `sharewithme-part-2`, `sharewithme-part-3`, etc. — so you can check out a tag instead of piecing the project together from the code snippets shown in the article.

## Routes are as follows

- __GET__: /health - Checks server health status
- __GET__: /version - Returns the app version
- __GET__: / - Renders the upload form (web UI)
- __POST__: / - Handles the upload form submission
- __POST__: /api/v1/objects/list - Lists all objects in the bucket defined by the PAR
- __POST__: /api/v1/objects - Uploads an object to the bucket defined by the PAR

### 🩺 Health
Simple endpoint to check whether the server is alive, giving back `200 OK`

- __URL:__ http://localhost:8080/health
- __HTTPMethod:__ `GET`

```
$ curl -i http://localhost:8080/health

HTTP/1.1 200 OK
Content-Length: 0
Date: Wed, 15 Jul 2026 10:00:00 GMT
Server: sharewithme
```

### Web

The same upload flow as the API, through a browser form instead of a JSON/binary request.

---
#### Renders the upload form
---

Pre-fills the PAR URL field from a cookie set by the previous upload, and shows a success or error message via the `uploaded`/`error` query parameters set by the redirect below.

- __URL:__ http://localhost:8080/
- __HTTPMethod:__ `GET`

---
#### Handles the upload form submission
---

Submitted as `multipart/form-data` with two parts:
- `parURL`: the Pre-Authenticated Request URL of the bucket
- `file`: the file to upload

- __URL:__ http://localhost:8080/
- __HTTPMethod:__ `POST`

```
$ curl -X "POST" "http://localhost:8080/" \
     -F "parURL=https://objectstorage.<region>.oraclecloud.com/p/<token>/n/<namespace>/b/<bucket>/o/" \
     -F "file=@photo.jpg"
```

On success, redirects to `/?uploaded=photo.jpg`; on failure, to `/?error=true`. Either way, the PAR URL is remembered in a cookie for 30 days so it doesn't need to be re-entered.

---
#### Lists all objects in the bucket defined by the PAR
---

The PAR URL is sent as JSON in the request body:
- `parURL`: the Pre-Authenticated Request URL of the bucket

- __URL:__ http://localhost:8080/api/v1/objects/list
- __HTTPMethod:__ `POST`

```
$ curl -X "POST" "http://localhost:8080/api/v1/objects/list" \
     -H 'Content-Type: application/json' \
     -d $'{
  "parURL": "https://objectstorage.<region>.oraclecloud.com/p/<token>/n/<namespace>/b/<bucket>/o/"
}'
```

__Return value:__
An array of object names

```
[
   "photo.jpg",
   "document.pdf"
]
```

---
#### Uploads an object to the bucket defined by the PAR
---

The metadata is sent as query parameters, the request body is the raw file content:
- `objectName`: the name the object will be stored under
- `parURL`: the Pre-Authenticated Request URL of the bucket

`--url-query` (curl 7.87+) percent-encodes the PAR URL automatically.

- __URL:__ http://localhost:8080/api/v1/objects
- __HTTPMethod:__ `POST`

```
$ curl -X "POST" "http://localhost:8080/api/v1/objects" \
     --url-query "objectName=photo.jpg" \
     --url-query "parURL=https://objectstorage.<region>.oraclecloud.com/p/<token>/n/<namespace>/b/<bucket>/o/" \
     -H 'Content-Type: application/octet-stream' \
     --data-binary @photo.jpg
```

__Return value:__
- `201 Created`
