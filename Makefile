## Configuration
## =============

# Have zero effect by default to prevent accidental changes.
.DEFAULT_GOAL := help

# Delete targets that fail to prevent subsequent attempts incorrectly assuming
# the target is up to date.
.DELETE_ON_ERROR: ;

# Prevent pesky default rules from creating unexpected dependency graphs.
.SUFFIXES: ;


## Verbs
## =====

help:
	@mkhelp $(firstword $(MAKEFILE_LIST)) ||:

## Prepare artifacts that are built in a container
pre-build: \
		build/aarch64/hello-world/_envoy \
		build/armv7hf/hello-world/_envoy \
		build/host/hello-world/_envoy \
		build/aarch64/web-server/_envoy \
		build/armv7hf/web-server/_envoy

## Checks
## ------

## Run all other checks
check_all: check_build check_format check_lint
.PHONY: check_all

## Check that all crates can be built
check_build:
	CARGO_PROFILE_DEFAULT_PANIC="abort" \
	cargo build
.PHONY: check_build

## Check that the code is formatted correctly
check_format:
	find apps -type f -name '*.rs' \
	| xargs rustfmt \
		--check \
		--config imports_granularity=Crate \
		--config group_imports=StdExternalCrate \
		--edition 2021
	cargo fmt --check
.PHONY: check_format

## Check that the code is free of lints
check_lint:
	CARGO_PROFILE_DEFAULT_PANIC="abort" \
	cargo clippy \
		--all-targets \
		--no-deps
		-- \
		-Dwarnings
.PHONY: check_lint

## Fixes
## -----

## Attempt to fix formatting automatically
fix_format:
	find apps -type f -name '*.rs' \
	| xargs rustfmt \
		--config imports_granularity=Crate \
		--config group_imports=StdExternalCrate \
		--edition 2021
	cargo fmt
.PHONY: fix_format

## Attempt to fix lints automatically
fix_lint:
	CARGO_PROFILE_DEFAULT_PANIC="abort" \
	cargo clippy --fix
.PHONY: fix_lint

## Nouns
## =====

build/examples/_envoy:
	git clone git@github.com:AxisCommunications/acap-native-sdk-examples.git $(@D)
	cd $(@D) \
    && git checkout 90f695ab536f865a65446bbc4f2797d9a6aee153
	touch $@

build/host/hello-world/_envoy: build/examples/_envoy
	rm -r $(@D) ||:
	mkdir -p $(dir $(@D))
	cp -r $(<D)/hello-world/app $(@D)
	cd $(@D) \
	&& STRIP=strip make
	touch $@

build/%/hello-world/_envoy: build/examples/_envoy
	rm -r $(@D) ||:
	mkdir -p $(dir $(@D))
	cd $(<D)/hello-world \
	&& docker build \
		--build-arg ARCH=$* \
		--tag hello-world-$* \
		.
	docker cp $$(docker create hello-world-$*):/opt/app $(@D)
	touch $@

build/%/hello-world.a: build/%/hello-world/_envoy
	ar crv $@ $(<D)/hello_world

build/%/hello-world.tar.gz: build/%/hello-world/_envoy
	tar -czf $@ $(<D)/hello_world

build/%/web-server/_envoy: build/examples/_envoy
	rm -r $(@D) ||:
	mkdir -p $(dir $(@D))
	cd $(<D)/web-server \
	&& docker build \
		--build-arg ARCH=$* \
		--tag web-server-$* \
		.
	docker cp $$(docker create web-server-$*):/opt/app $(@D)
	touch $@

build/%/web-server.a: build/%/web-server/_envoy
	ar crv $@ $(<D)/web_server_rev_proxy $(<D)/lib/libmonkey.so.1.5

build/%/web-server.tar.gz: build/%/web-server/_envoy
	tar -czf $@ $(<D)/web_server_rev_proxy $(<D)/lib

results/the-size-of-hello-syslog-on-aarch64.txt: build/aarch64/hello-world.a
	./bin/build-use-case-with-all-presets-for-target.sh hello-syslog aarch64-unknown-linux-gnu
	find artifacts/aarch64-unknown-linux-gnu -name 'hello-syslog--*' \
	| LC_ALL=C sort \
	| xargs du --apparent-size > $@
	du --apparent-size $^ >> $@

results/the-size-of-apps-on-different-targets.txt: \
		build/aarch64/hello-world.a \
		build/aarch64/hello-world.tar.gz \
		build/aarch64/web-server.a \
		build/aarch64/web-server.tar.gz \
		build/armv7hf/hello-world.a \
		build/armv7hf/hello-world.tar.gz \
		build/armv7hf/web-server.a \
		build/armv7hf/web-server.tar.gz \
		build/host/hello-world.a \
		build/host/hello-world.tar.gz
	du \
		--apparent-size \
		--si \
		build/aarch64/hello-world/hello_world \
		$^ > $@
