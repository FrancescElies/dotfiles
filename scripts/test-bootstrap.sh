#!/usr/bin/env bash
set -euo pipefail
podman run --rm -it -v "$PWD:/dotfiles:Z" debian:latest bash -c '
  apt-get update && apt-get install -y git curl sudo &&
  curl -sSL https://github.com/nushell/nushell/releases/download/0.116.1/nu-0.116.1-x86_64-unknown-linux-gnu.tar.gz -o /tmp/nu.tar.gz &&
  tar -xzf /tmp/nu.tar.gz -C /usr/local/bin --strip-components=1 &&
  cd /dotfiles && nu -c "use toolkit.nu; toolkit bootstrap"
'
