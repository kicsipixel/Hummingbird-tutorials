# Tailwind

Hummingbird server framework with Tailwind CSS integration using SwiftKaze.

## Requirements

- Swift 6.2+
- Docker (for containerized deployment)

## Local Development

```bash
# Build and run
swift run App
```

Visit http://localhost:8080

## Docker

```bash
# Build
docker build -t tailwind-app .

# Run
docker run -p 8080:8080 tailwind-app
```

## Dockerfile Changes for Tailwind CSS

Two modifications to the standard Hummingbird Dockerfile:

### 1. Build Stage (after copying SPM resources)

```dockerfile
# ================================
# BEGIN: Tailwind CSS / SwiftKaze
# ================================
RUN swift build --package-path /build -c release --product "PrepareCSS" \
    && cp "$(swift build --package-path /build -c release --show-bin-path)/PrepareCSS" ./ \
    && cd /build && /staging/PrepareCSS && cd /staging
# ================================
# END: Tailwind CSS / SwiftKaze
# ================================
```

### 2. Run Image (add libcurl4)

```dockerfile
libcurl4 \
```

Add to the apt-get install list (required by FoundationNetworking).
