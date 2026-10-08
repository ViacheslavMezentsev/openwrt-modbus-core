PROJECT := modbus-rtu-core
DEMO := modbus-demo
VERSION ?= 0.2.0
OUT_DIR := out
HELPER_SCRIPTS := scripts/build-ipk.sh scripts/ci_verify.sh scripts/deploy.sh scripts/install-ipk-on-router.sh scripts/make_repo.sh scripts/router-clean-opkg-cache.sh scripts/run-tests.sh scripts/test-core-demo-router.sh scripts/test-opkg-lifecycle.sh

.PHONY: all prepare build build-core build-demo test verify checksums repo deploy-core deploy-demo install-ipk test-core-demo-router test-opkg router-clean clean

all: build test verify checksums

prepare:
	chmod +x $(HELPER_SCRIPTS)
	chmod +x pkg/CONTROL/postinst pkg/CONTROL/prerm pkg/etc/init.d/modbus-rtu-core pkg/usr/bin/modbusd pkg/www/cgi-bin/modbus-core-status
	chmod +x pkg-demo/CONTROL/postinst pkg-demo/CONTROL/prerm pkg-demo/etc/init.d/modbus-demo pkg-demo/usr/bin/modbus-demo pkg-demo/www/cgi-bin/modbus-demo-status

build: build-core build-demo

build-core: prepare
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

build-demo: prepare
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg-demo OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

test:
	./scripts/run-tests.sh

verify:
	./scripts/ci_verify.sh

checksums: build
	sha256sum $(OUT_DIR)/*.ipk > $(OUT_DIR)/checksums.sha256

repo: build
	./scripts/make_repo.sh

deploy-core:
	./scripts/deploy.sh pkg $(PROJECT)

deploy-demo:
	./scripts/deploy.sh pkg-demo $(DEMO)

install-ipk: build
	BUILD_VERSION=$(VERSION) ./scripts/install-ipk-on-router.sh

test-opkg: build
	BUILD_VERSION=$(VERSION) ./scripts/test-opkg-lifecycle.sh

test-core-demo-router: build
	BUILD_VERSION=$(VERSION) ./scripts/test-core-demo-router.sh

.PHONY: test-bluepill-router
test-bluepill-router:
	sh scripts/test-bluepill-router.sh

router-clean:
	./scripts/router-clean-opkg-cache.sh

clean:
	rm -rf $(OUT_DIR) repo
