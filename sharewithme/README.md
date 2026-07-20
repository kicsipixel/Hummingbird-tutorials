# Share files using OCI Object Storage

Example app using [OCIKit](https://github.com/iliasaz/oci-swift-sdk) to connect to Oracle Cloud Infrastructure (OCI) Object Storage. The app authenticates with an Instance Principal signer and works with buckets through Pre-Authenticated Requests (PAR), so the user can list the objects in the bucket and upload new ones.

This project accompanies the "From Zero to MicroSaaS" article series. Each article part has a matching git tag with the complete, working state of the code at that point — `sharewithme-part-1`, `sharewithme-part-2`, `sharewithme-part-3`, etc. — so you can check out a tag instead of piecing the project together from the code snippets shown in the article.

## Routes are as follows

- __GET__: /health - Checks server health status
- __GET__: /version - Returns the app version
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

### Objects
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
