#!/usr/bin/env bash
set -eux

# Beware of feature unification

package=$1
preset=$2
target=$3

ARTIFACT_DIR="artifacts/${target}/${preset}"
export CARGO_TARGET_DIR="targets/${target}/${preset}"

# Location detail is separate from trim-paths https://rust-lang.github.io/rfcs/3127-trim-paths.html

case $preset in
  stable-dev)
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile=dev
    ;;
  stable-release)
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile=release
    ;;
  stable-conservative)
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile=conservative
    ;;
  stable-aggressive)
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile=aggressive
    ;;
  unstable-conservative)
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile='unstable-conservative' --config='profile.unstable-conservative.inherits="conservative"' \
      -Zbuild-std=std
    ;;
  unstable-aggressive)
    RUSTFLAGS=" -Zlocation-detail=none -Zfmt-debug=none -Clink-args=-lc" \
    cargo +nightly build -Zunstable-options --artifact-dir=${ARTIFACT_DIR} --package=${package} --target=${target} --profile='unstable-aggressive' --config='profile.unstable-aggressive.inherits="aggressive"' \
      -Zbuild-std=std,panic_abort \
      -Zbuild-std-features=optimize_for_size,panic_immediate_abort
    ;;
  *)
    exit 1
esac
