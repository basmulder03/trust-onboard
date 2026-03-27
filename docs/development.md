# Development

## Local commands

```bash
go run ./cmd/trust-onboard validate --config config.example.yaml
go run ./cmd/trust-onboard serve --config config.example.yaml
go run ./cmd/trust-onboard generate --config config.example.yaml --output-dir ./dist
go run ./cmd/trust-onboard print-fingerprint --config config.example.yaml
go run ./cmd/trust-onboard generate --config config.example.yaml --output-dir ./dist
go run ./cmd/trust-onboard print-fingerprint --config config.example.yaml
```

## Build

```bash
go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard ./cmd/trust-onboard
```

Or:

```bash
make build
```

## Cross compile examples

Linux amd64:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-linux-amd64 ./cmd/trust-onboard
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-linux-arm64 ./cmd/trust-onboard
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-darwin-arm64 ./cmd/trust-onboard
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-windows-amd64.exe ./cmd/trust-onboard
```
