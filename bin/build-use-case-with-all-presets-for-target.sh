#!/usr/bin/env bash
set -ux

use_case=${1:-hello-syslog}
target=${2:-aarch64-unknown-linux-gnu}

for package_dir in apps/${use_case}/*; do
  package=${use_case}--`basename ${package_dir}`
  for preset in stable-{dev,release} {,un}stable-{conservative,aggressive}; do
    ./bin/build-package-with-preset-for-target.sh $package $preset $target;
  done
done