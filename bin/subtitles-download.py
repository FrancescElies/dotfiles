#!/usr/bin/env python3

"""
OpenSubtitles Smart Subtitle Downloader

Install:
    pip install requests guessit

API KEY:
    https://www.opensubtitles.com/consumers

Account:
    https://www.opensubtitles.com/

Usage:
    python subtitles.py "City Of God (2002).mkv"
    python subtitles.py "City Of God (2002).mkv" en

Optional environment variables:
    OPENSUBTITLES_API_KEY
    OPENSUBTITLES_USERNAME
    OPENSUBTITLES_PASSWORD

Features:
    - Calculates OpenSubtitles movie hash
    - Searches using hash + filename
    - Scores all returned subtitles
    - Prefers exact hash matches
    - Compares release names
    - Compares FPS when ffprobe is installed
    - Prefers trusted uploaders
    - Prefers regular subtitles over SDH
    - Uses downloads and ratings as tie-breakers
    - Downloads the best-ranked subtitle
"""

import argparse
import os
import struct
import subprocess
import sys
from difflib import SequenceMatcher
from pathlib import Path

import requests
from guessit import guessit

# =========================================================
# CONFIGURATION
# =========================================================

API_KEY = os.getenv("OPENSUBTITLES_API_KEY", "YOUR_API_KEY")

USERNAME = os.getenv("OPENSUBTITLES_USERNAME", "")
PASSWORD = os.getenv("OPENSUBTITLES_PASSWORD", "")

BASE_URL = "https://api.opensubtitles.com/api/v1"

HEADERS = {
    "Api-Key": API_KEY,
    "Content-Type": "application/json",
    "Accept": "application/json",
    "User-Agent": "SmartSubtitleDownloader v2.0",
}

CHUNK_SIZE = 65536

# Set True to prefer regular subtitles over hearing-impaired.
PREFER_REGULAR = True


# =========================================================
# MOVIE HASH
# =========================================================


def calculate_movie_hash(filename):

    size = os.path.getsize(filename)

    if size < CHUNK_SIZE * 2:
        print("File too small for OpenSubtitles hash.")
        return None

    checksum = size & 0xFFFFFFFFFFFFFFFF

    with open(filename, "rb") as f:
        for offset in (0, size - CHUNK_SIZE):
            f.seek(offset)
            data = f.read(CHUNK_SIZE)

            for i in range(0, CHUNK_SIZE, 8):
                value = struct.unpack_from("<Q", data, i)[0]

                checksum = (checksum + value) & 0xFFFFFFFFFFFFFFFF

    return f"{checksum:016x}"


# =========================================================
# VIDEO FPS (OPTIONAL FFMPEG)
# =========================================================


def get_video_fps(filename):

    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=avg_frame_rate",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(filename),
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )

        value = result.stdout.strip()

        if "/" in value:
            numerator, denominator = map(float, value.split("/"))

            if denominator:
                return numerator / denominator

        elif value:
            return float(value)

    except (FileNotFoundError, ValueError, subprocess.SubprocessError):
        pass

    return None


# =========================================================
# AUTHENTICATION
# =========================================================


def login():

    if not USERNAME or not PASSWORD:
        print("No account credentials configured.")
        print("Will attempt API-key-only download.")
        return None

    print("Logging into OpenSubtitles...")

    try:
        response = requests.post(
            f"{BASE_URL}/login",
            headers=HEADERS,
            json={"username": USERNAME, "password": PASSWORD},
            timeout=30,
        )

        response.raise_for_status()

        token = response.json().get("token")

        if token:
            print("Login successful.")
            return token

        print("Login response did not contain a token.")

    except requests.RequestException as e:
        print(f"Login failed: {e}")

    return None


# =========================================================
# SEARCH
# =========================================================


def search_subtitles(movie, title, year, language, movie_hash):

    params = {"query": movie.name, "languages": language, "type": "movie"}

    if year:
        params["year"] = year

    if movie_hash:
        params["moviehash"] = movie_hash

    print("\nSearching OpenSubtitles...")

    response = requests.get(
        f"{BASE_URL}/subtitles", headers=HEADERS, params=params, timeout=30
    )

    response.raise_for_status()

    return response.json().get("data", [])


# =========================================================
# RELEASE SIMILARITY
# =========================================================


def release_similarity(movie_name, subtitle_release):

    if not subtitle_release:
        return 0

    return SequenceMatcher(None, movie_name.lower(), subtitle_release.lower()).ratio()


# =========================================================
# SUBTITLE SCORING
# =========================================================


def score_subtitle(item, movie, movie_fps):

    attr = item.get("attributes", {})

    score = 0
    reasons = []

    # -----------------------------------------------------
    # 1. EXACT MOVIE HASH MATCH
    # -----------------------------------------------------

    hash_match = (
        attr.get("moviehash_match") is True or item.get("moviehash_match") is True
    )

    if hash_match:
        score += 10000
        reasons.append("EXACT MOVIE HASH MATCH")

    # -----------------------------------------------------
    # 2. RELEASE NAME MATCH
    # -----------------------------------------------------

    release = attr.get("release", "")

    similarity = release_similarity(movie.stem, release)

    release_score = int(similarity * 100)

    score += release_score

    if similarity >= 0.75:
        reasons.append(f"Strong release match ({similarity:.0%})")

    elif similarity >= 0.40:
        reasons.append(f"Partial release match ({similarity:.0%})")

    # -----------------------------------------------------
    # 3. FPS MATCH
    # -----------------------------------------------------

    subtitle_fps = attr.get("fps")

    if movie_fps and subtitle_fps:
        difference = abs(float(movie_fps) - float(subtitle_fps))

        if difference <= 0.01:
            score += 200
            reasons.append("FPS MATCH")

        elif difference <= 0.5:
            score += 50
            reasons.append("Close FPS")

        else:
            score -= 100
            reasons.append("FPS MISMATCH")

    # -----------------------------------------------------
    # 4. HEARING IMPAIRED
    # -----------------------------------------------------

    hearing_impaired = attr.get("hearing_impaired", False)

    if PREFER_REGULAR:
        if hearing_impaired:
            score -= 100
            reasons.append("Hearing-impaired subtitle")

        else:
            score += 50
            reasons.append("Regular subtitle")

    # -----------------------------------------------------
    # 5. TRUSTED UPLOADER
    # -----------------------------------------------------

    if attr.get("from_trusted"):
        score += 100
        reasons.append("Trusted uploader")

    # -----------------------------------------------------
    # 6. DOWNLOAD COUNT
    # -----------------------------------------------------

    downloads = attr.get("download_count", 0) or 0

    download_score = min(int(downloads / 100), 100)

    score += download_score

    # -----------------------------------------------------
    # 7. RATINGS
    # -----------------------------------------------------

    rating = attr.get("ratings", 0) or 0

    score += int(float(rating) * 10)

    if rating:
        reasons.append(f"Rating: {rating}")

    return score, reasons


# =========================================================
# RANK ALL RESULTS
# =========================================================


def rank_subtitles(results, movie, movie_fps):

    ranked = []

    for item in results:
        score, reasons = score_subtitle(item, movie, movie_fps)

        attr = item.get("attributes", {})

        ranked.append(
            {
                "item": item,
                "score": score,
                "reasons": reasons,
                "release": attr.get("release", "Unknown"),
                "downloads": attr.get("download_count", 0),
                "fps": attr.get("fps", 0),
                "trusted": attr.get("from_trusted", False),
            }
        )

    ranked.sort(key=lambda x: x["score"], reverse=True)

    return ranked


# =========================================================
# DOWNLOAD
# =========================================================


def download_subtitle(best, movie, language, token):

    item = best["item"]

    files = item.get("attributes", {}).get("files", [])

    if not files:
        print("No downloadable files.")
        return

    file_id = files[0]["file_id"]

    headers = HEADERS.copy()

    if token:
        headers["Authorization"] = f"Bearer {token}"

    print("\nRequesting subtitle download...")

    response = requests.post(
        f"{BASE_URL}/download",
        headers=headers,
        json={"file_id": file_id, "sub_format": "srt"},
        timeout=30,
    )

    if response.status_code == 401:
        print("\nHTTP 401: Download authorization failed.")
        print("Check your OpenSubtitles credentials.")
        print("Also check your download allowance.")
        return

    response.raise_for_status()

    download_url = response.json().get("link")

    if not download_url:
        print("No download URL returned.")
        return

    print("Downloading subtitle file...")

    subtitle = requests.get(download_url, timeout=60)

    subtitle.raise_for_status()

    output_path = movie.with_suffix(f".{language}.srt")

    output_path.write_bytes(subtitle.content)

    print("\nSUCCESS!")
    print(f"Saved: {output_path}")


# =========================================================
# MAIN
# =========================================================


def main():

    parser = argparse.ArgumentParser(description="OpenSubtitles smart subtitle downloader")
    parser.add_argument("movie", help="movie file")
    parser.add_argument("language", nargs="?", default="en", help="language code (en, es, tr, ...)")
    parser.add_argument("-l", "--language", dest="lang_flag", help="language code (en, es, tr, ...)")
    parser.add_argument("-f", "--force", action="store_true", help="download even if subtitle already exists")
    args = parser.parse_args()

    movie = Path(args.movie)
    language = args.lang_flag or args.language

    VIDEO_EXTS = {".mkv", ".mp4", ".avi", ".m4v", ".mov", ".wmv", ".flv", ".webm"}

    if movie.is_dir():
        files = [f for f in sorted(movie.rglob("*")) if f.is_file() and f.suffix.lower() in VIDEO_EXTS]
        total = len(files)
        for i, f in enumerate(files, 1):
            print(f"\n[{i}/{total}] {f}")
            sys.argv = [sys.argv[0], str(f), language] + (["-f"] if args.force else [])
            main()
        return

    if not movie.is_file():
        print("Movie file not found.")
        return

    output_path = movie.with_suffix(f".{language}.srt")
    if output_path.exists() and not args.force:
        print(f"Subtitle already exists: {output_path}")
        print("Use -f to download anyway.")
        return

    if API_KEY == "YOUR_API_KEY":
        print("Configure your API key first:")
        print("https://www.opensubtitles.com/consumers")
        return

    info = guessit(movie.name)

    title = info.get("title", movie.stem)
    year = info.get("year")

    print("\n===================================")
    print(" SMART SUBTITLE DOWNLOADER")
    print("===================================")

    print(f"Movie:    {title}")
    print(f"Year:     {year}")
    print(f"Language: {language}")

    # Calculate movie hash

    print("\nCalculating movie hash...")

    movie_hash = calculate_movie_hash(movie)

    if movie_hash:
        print(f"Movie hash: {movie_hash}")

    # Get FPS

    movie_fps = get_video_fps(movie)

    if movie_fps:
        print(f"Video FPS: {movie_fps:.3f}")

    else:
        print("Video FPS: Unknown (ffprobe unavailable)")

    # Search

    try:
        results = search_subtitles(movie, title, year, language, movie_hash)

    except requests.RequestException as e:
        print(f"Search failed: {e}")
        return

    if not results:
        print("No subtitles found.")
        return

    print(f"\nFound {len(results)} subtitle results.")

    # Rank

    ranked = rank_subtitles(results, movie, movie_fps)

    # Display top 5

    print("\n===================================")
    print(" TOP 5 SUBTITLE CANDIDATES")
    print("===================================")

    for index, candidate in enumerate(ranked[:5], 1):
        print(f"\n#{index} Score: {candidate['score']}")
        print(f"Release: {candidate['release']}")
        print(f"FPS: {candidate['fps']}")
        print(f"Downloads: {candidate['downloads']}")
        print(f"Trusted: {candidate['trusted']}")

        for reason in candidate["reasons"]:
            print(f"  + {reason}")

    # Best result

    best = ranked[0]

    print("\n===================================")
    print(" SELECTED SUBTITLE")
    print("===================================")

    print(f"Release: {best['release']}")
    print(f"Score: {best['score']}")

    if not any("EXACT MOVIE HASH MATCH" in reason for reason in best["reasons"]):
        print("WARNING: No exact hash match selected.")

    # Authenticate and download

    token = login()

    try:
        download_subtitle(best, movie, language, token)

    except requests.RequestException as e:
        print(f"\nDownload failed: {e}")


if __name__ == "__main__":
    main()
