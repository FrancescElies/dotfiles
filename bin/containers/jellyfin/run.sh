#!/usr/bin/env bash
# Run Jellyfin in a rootless Podman container, exposing ~/Music and ~/Videos.
# For hardware acceleration: sudo setsebool -P container_use_dri_devices 1
set -euo pipefail

podman run -d --name jellyfin \
  --label "io.containers.autoupdate=registry" \
  --publish 8096:8096/tcp \
  --publish 7359:7359/udp \
  --device /dev/dri/ \
  --user "$(id -u):$(id -g)" \
  --userns keep-id \
  --volume jellyfin-cache:/cache:Z \
  --volume jellyfin-config:/config:Z \
  --mount type=bind,source="$HOME/Music",destination=/media/Music,ro=true,relabel=private \
  --mount type=bind,source="$HOME/Videos",destination=/media/Videos,ro=true,relabel=private \
  docker.io/jellyfin/jellyfin:latest
