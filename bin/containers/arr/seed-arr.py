#!/usr/bin/env python3
import json
import os
import sys
import urllib.request
from pathlib import Path


def key_from(path: Path):
    try:
        return path.read_text().split("<ApiKey>")[1].split("</ApiKey>")[0]
    except (FileNotFoundError, IndexError):
        return None


def req(url, key, path, method="GET", data=None):
    r = urllib.request.Request(
        url + path,
        data=data,
        method=method,
        headers={"X-Api-Key": key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        print(e.code, e.read().decode(), file=sys.stderr)
        raise


# Prowlarr
purl = os.getenv("PROWLARR_URL", "http://localhost:9696").rstrip("/")
pkey = os.getenv("PROWLARR_API_KEY") or key_from(
    Path("/media/cesc/data/arr/config/prowlarr/config.xml")
)
if pkey:
    schema = req(purl, pkey, "/api/v1/indexer/schema")
    for item in schema:
        if item.get("name") in {"1337x", "The Pirate Bay", "Nyaa", "EZTV", "YTS"}:
            item["appProfileId"] = 1
            item["enable"] = True
            try:
                req(purl, pkey, "/api/v1/indexer", "POST", json.dumps(item).encode())
                print("prowlarr added", item["name"])
            except Exception as e:
                print("prowlarr skipped", item["name"], "->", e)

# Radarr
rurl = os.getenv("RADARR_URL", "http://localhost:7878").rstrip("/")
rkey = os.getenv("RADARR_API_KEY") or key_from(
    Path("/media/cesc/data/arr/config/radarr/config.xml")
)
if rkey:
    try:
        req(
            rurl,
            rkey,
            "/api/v3/rootfolder",
            "POST",
            json.dumps({"path": "/data/media"}).encode(),
        )
        print("radarr root folder added")
    except Exception as e:
        print("radarr root folder:", e)
    try:
        req(
            rurl,
            rkey,
            "/api/v3/downloadclient",
            "POST",
            json.dumps(
                {
                    "name": "qbittorrent",
                    "implementation": "QBittorrent",
                    "configContract": "QBittorrentSettings",
                    "enable": True,
                    "priority": 1,
                    "fields": [
                        {"name": "host", "value": "qbittorrent"},
                        {"name": "port", "value": 8081},
                        {"name": "username", "value": "admin"},
                        {
                            "name": "password",
                            "value": os.getenv("QBIT_PASSWORD")
                            or Path(
                                "/media/cesc/data/arr/config/qbittorrent/password", "r"
                            )
                            .read_text()
                            .strip()
                            if Path(
                                "/media/cesc/data/arr/config/qbittorrent/password"
                            ).exists()
                            else "",
                        },
                        {"name": "category", "value": "radarr"},
                    ],
                    "categories": ["radarr"],
                }
            ).encode(),
        )
        print("radarr download client added")
    except Exception as e:
        print("radarr download client:", e)
