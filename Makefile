APP := trust-onboard
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null | sed 's/^v//' || printf 'dev')
PACKAGE_ARCH ?= amd64
RPM_ARCH ?= x86_64

.PHONY: build
build:
	go build -trimpath -ldflags="-s -w" -o bin/$(APP) ./cmd/$(APP)

.PHONY: run
run:
	go run ./cmd/$(APP) serve --config config.example.yaml

.PHONY: validate
validate:
	go run ./cmd/$(APP) validate --config config.example.yaml

.PHONY: generate
generate:
	go run ./cmd/$(APP) generate --config config.example.yaml --output-dir ./dist

.PHONY: clean
clean:
	rm -rf ./bin ./dist

.PHONY: package-configure
package-configure:
	mkdir -p ./dist/package-root/etc/trust-onboard ./dist/package-root/usr/local/bin ./dist/package-root/usr/lib/systemd/system ./dist/package-root/var/lib/trust-onboard/assets
	cp ./config.example.yaml ./dist/package-root/etc/trust-onboard/config.yaml
	cp ./packaging/trust-onboard.service ./dist/package-root/usr/lib/systemd/system/trust-onboard.service
	cp ./assets/logo.svg ./dist/package-root/var/lib/trust-onboard/assets/logo.svg
	cp ./assets/root_ca.crt ./dist/package-root/var/lib/trust-onboard/assets/root_ca.crt
	cp ./bin/$(APP) ./dist/package-root/usr/local/bin/$(APP)

.PHONY: package-deb
package-deb: build package-configure
	VERSION=$(VERSION) PACKAGE_ARCH=$(PACKAGE_ARCH) nfpm package --packager deb --target ./dist/$(APP)_$(VERSION)_linux_$(PACKAGE_ARCH).deb --config ./packaging/nfpm.yaml

.PHONY: package-rpm
package-rpm: build package-configure
	VERSION=$(VERSION) PACKAGE_ARCH=$(PACKAGE_ARCH) nfpm package --packager rpm --target ./dist/$(APP)-$(VERSION)-1.$(RPM_ARCH).rpm --config ./packaging/nfpm.yaml

.PHONY: package-deb-arm64
package-deb-arm64: build-linux-arm64 package-configure
	VERSION=$(VERSION) PACKAGE_ARCH=arm64 nfpm package --packager deb --target ./dist/$(APP)_$(VERSION)_linux_arm64.deb --config ./packaging/nfpm.yaml

.PHONY: package-rpm-arm64
package-rpm-arm64: build-linux-arm64 package-configure
	VERSION=$(VERSION) PACKAGE_ARCH=arm64 nfpm package --packager rpm --target ./dist/$(APP)-$(VERSION)-1.aarch64.rpm --config ./packaging/nfpm.yaml

.PHONY: build-linux-arm64
build-linux-arm64:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o bin/$(APP) ./cmd/$(APP)

.PHONY: release-version
release-version:
	@printf '%s\n' '$(VERSION)'
