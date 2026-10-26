PROJECT := modbus-rtu-core
DEMO := modbus-demo
VERSION ?= 0.4.0
SCHOOLBELL_VERSION ?= $(shell sed -n 's/^Version: //p' pkg-schoolbell/CONTROL/control)
OUT_DIR := out
HELPER_SCRIPTS := scripts/build-ipk.sh scripts/ci_verify.sh scripts/deploy.sh scripts/install-ipk-on-router.sh scripts/make_repo.sh scripts/router-clean-opkg-cache.sh scripts/run-tests.sh scripts/test-core-demo-router.sh scripts/test-opkg-lifecycle.sh

.PHONY: all prepare build build-core build-demo build-schoolbell test verify checksums repo deploy-core deploy-demo install-ipk test-core-demo-router test-opkg router-clean clean

all: check-docs check-ci build test verify checksums

prepare:
	chmod +x pkg/usr/bin/modbus
	chmod +x $(HELPER_SCRIPTS)
	chmod +x pkg/CONTROL/postinst pkg/CONTROL/prerm pkg/etc/init.d/modbus-rtu-core pkg/usr/bin/modbusd pkg/www/cgi-bin/modbus-core-status
	chmod +x pkg-demo/CONTROL/postinst pkg-demo/CONTROL/prerm pkg-demo/etc/init.d/modbus-demo pkg-demo/usr/bin/modbus-demo pkg-demo/www/cgi-bin/modbus-demo-status

build: build-core build-demo build-schoolbell

build-core: prepare
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

build-demo: prepare
	BUILD_VERSION=$(VERSION) PKG_DIR=pkg-demo OUT_DIR=$(OUT_DIR) ./scripts/build-ipk.sh

build-schoolbell:
	python3 scripts/build-schoolbell.py --out $(OUT_DIR) --version $(SCHOOLBELL_VERSION)

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

.PHONY: test-topics-router
test-topics-router:
	sh scripts/test-topics-router.sh

router-clean:
	./scripts/router-clean-opkg-cache.sh

clean:
	rm -rf $(OUT_DIR) repo

.PHONY: check-docs check-ci ci-core ci-demo ci-schoolbell
check-docs:
	python3 scripts/check_docs.py

check-ci:
	python3 scripts/test_ci.py

ci-core:
	$(MAKE) build-core OUT_DIR=$(OUT_DIR)/ci-core
	CI_REQUIRE_TOOLS=1 sh scripts/run-tests.sh core
	python3 scripts/verify-component.py core $(OUT_DIR)/ci-core
	cd "$(OUT_DIR)/ci-core" && sha256sum *.ipk > checksums.sha256

ci-demo:
	$(MAKE) build-demo OUT_DIR=$(OUT_DIR)/ci-demo
	CI_REQUIRE_TOOLS=1 sh scripts/run-tests.sh demo
	python3 scripts/verify-component.py demo $(OUT_DIR)/ci-demo
	cd "$(OUT_DIR)/ci-demo" && sha256sum *.ipk > checksums.sha256

ci-schoolbell:
	sh scripts/test-schoolbell.sh
	$(MAKE) build-schoolbell OUT_DIR=$(OUT_DIR)/ci-schoolbell
	python3 scripts/verify-component.py schoolbell $(OUT_DIR)/ci-schoolbell
	cd "$(OUT_DIR)/ci-schoolbell" && sha256sum *.ipk > checksums.sha256

.PHONY: build-native-io test-native-io
build-native-io:
	$(MAKE) -C native/io

test-native-io:
	sh scripts/test-native-io.sh

.PHONY: test-schoolbell
test-schoolbell:
	sh scripts/test-schoolbell.sh

.PHONY: site check-site
site:
	python3 scripts/build-site.py

check-site: site
	python3 scripts/test-site.py
	node scripts/test-site-demo.js
	node scripts/test-schoolbell-ranges.js
	node scripts/test-schoolbell-session-ui.js
	node scripts/test-schoolbell-routes.js
	node scripts/test-schoolbell-backup-ui.js
	node scripts/test-schoolbell-media-ui.js

.PHONY: test-release-discovery
test-release-discovery:
	python3 scripts/test_release_discovery.py
