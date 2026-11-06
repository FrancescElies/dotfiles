# Arr stack

Services: bazarr, radarr, lidarr, prowlarr, flaresolverr, qbittorrent (readarr commented out).

## Start
1. Ensure `/dev/sda1` mounted at `/media/cesc/data` (see fstab).
2. Create folders: `mkdir -p /media/cesc/data/arr/config/{bazarr,lidarr,radarr,prowlarr,qbittorrent,downloads,media}`
3. `arr up` (or `podman compose up -d`)
4. Open UIs via `arr open <name>`.

## Notes
- qBittorrent web UI on port 8081.
- Use unified `/data` paths for atomic moves: media=`/data/media`, downloads=`/data/downloads`.
- Seed indexers: `PROWLARR_API_KEY=... python3 seed-prowlarr.py` (key from config.xml).
- VPN: add gluetun and route qbittorrent through it (TODO).