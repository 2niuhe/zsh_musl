SHELL := /bin/sh

VERSION := 5.9.2
TARGET ?= linux-amd64-musl

.PHONY: all build package verify clean

all: build verify package

build:
	case "$(TARGET)" in \
	  linux-amd64-musl|linux-arm64-musl) ./scripts/build-linux.sh --target "$(TARGET)" ;; \
	  darwin-amd64|darwin-arm64) ./scripts/build-macos.sh --target "$(TARGET)" ;; \
	  *) echo "unsupported TARGET=$(TARGET)" >&2; exit 1 ;; \
	esac

package:
	./scripts/package.sh --target "$(TARGET)"

verify:
	./scripts/verify.sh --target "$(TARGET)"

clean:
	rm -rf build dist

