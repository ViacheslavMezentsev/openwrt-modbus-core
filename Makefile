PROJECT := modbus-rtu-core
DEMO := modbus-demo
VERSION ?= 0.1.0
OUT_DIR := out

.PHONY: all build build-core build-demo test verify repo deploy-core deploy-demo router-clean clean

all: build verify

build: build-core build-demo

build-core:
	chmod +x scripts/build-ipk.sh scripts/deploy.sh scripts/ci_verify.sh scripts/make_repo.sh
	chmod +x scripts/router-clean-opkg-cache.sh
	chmod +x pkg/CONTROL/postinst pkg/CONTROL/prerm pkg/etc/init.d/modbus-rtu-core pkg/usr/bin/modbusd pkg/www/cgi-bin/modbus-core-status
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

build-demo:
	chmod +x scripts/build-ipk.sh scripts/deploy.sh scripts/ci_verify.sh scripts/make_repo.sh
	chmod +x scripts/router-clean-opkg-cache.sh
	chmod +x pkg-demo/CONTROL/postinst pkg-demo/CONTROL/prerm pkg-demo/etc/init.d/modbus-demo pkg-demo/usr/bin/modbus-demo pkg-demo/www/cgi-bin/modbus-demo-status
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg-demo OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

test:
	@if command -v lua >/dev/null 2>&1; then \
		lua scripts/test_core.lua; \
	else \
		echo "[test] skipped: lua is not installed in WSL"; \
	fi

verify:
	./scripts/ci_verify.sh

repo: build
	./scripts/make_repo.sh

deploy-core:
	./scripts/deploy.sh pkg $(PROJECT)

deploy-demo:
	./scripts/deploy.sh pkg-demo $(DEMO)

router-clean:
	./scripts/router-clean-opkg-cache.sh

clean:
	rm -rf $(OUT_DIR) repo
