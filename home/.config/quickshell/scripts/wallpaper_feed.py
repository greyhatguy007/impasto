#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   W A L L P A P E R   F E E D                                             │
# │   wallpapers from whatever provider the settings name · full size       │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Wallpaper providers for the gallery in Settings → Integrations.

A provider is a source of photographs that can be searched and fetched
whole. The shell does not care which one answered — the photos come back in
one shape, at the width the settings ask for, and the shell downloads them
itself:

    wallhaven   keyless, 4K-first, searched by tag. The default, because it
                needs no account and hands over the original file.
    unsplash    needs an access key; the raw URL is asked for a sized JPEG.
    pexels      needs an API key; the original file, as uploaded.
    openverse   keyless, a search across openly licensed sources.
    picsum      keyless, a curated set; the topic only picks within it.

Sizes: a wallpaper is fetched at `wallpaperWidth` (default 2560, the widest
monitor most desks have) rather than the thumbnail a provider would serve,
so nothing arrives smaller than the screen it is about to fill. A provider
with no resizing endpoint is asked for its original and cropped by the
scaler parameter it does have.

Every photo is handed to the shell as a job the shell fetches itself, with
this process' stdout kept for the JSON report. A failure is reported as
`{"available": false, "reason": ...}`, never a traceback, in the shape the
other integration scripts use.

Commands:

    providers   what can be searched, and whether a key is needed
    search      photos for the topic, as a list of jobs
"""

import json
import os
import random
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 15
AGENT = "impasto-quickshell/1.0 (https://github.com/andreumassanet/impasto)"

WALLHAVEN_SEARCH = "https://wallhaven.cc/api/v1/search"
UNSPLASH_SEARCH = "https://api.unsplash.com/search/photos"
PEXELS_SEARCH = "https://api.pexels.com/v1/search"
OPENVVERSE_SEARCH = "https://api.openverse.org/v1/images/"
PICSUM_LIST = "https://picsum.photos/v2/list"

# The width a wallpaper is fetched at when the settings say nothing: wide
# enough for a 1440p panel, small enough to keep the download civil.
DEFAULT_WIDTH = 2560

# What each provider needs before it can be searched.
NEEDS_KEY = ["unsplash", "pexels"]


def state_directory():
    return os.path.join(
        os.environ.get("XDG_STATE_HOME")
        or os.path.expanduser("~/.local/state"),
        "quickshell",
    )


def settings():
    """The provider, the topic, the key and the width, from the shell.

    The `unsplash*` keys are what this used to be called, and a machine set
    up before the rename still points at the same gallery, so they are read
    as a fallback rather than dropped.
    """
    path = os.path.join(state_directory(), "settings.json")
    try:
        with open(path, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        stored = {}

    def text(*names, default=""):
        for name in names:
            value = stored.get(name)
            if value not in (None, ""):
                return str(value).strip()
        return default

    provider = text("wallpaperProvider", default="wallhaven")
    width = 0
    try:
        width = int(stored.get("wallpaperWidth") or 0)
    except (TypeError, ValueError):
        width = 0
    return {
        "provider": provider,
        "topic": text("wallpaperQuery", "unsplashQuery", default="nature"),
        "key": text("wallpaperKey", "unsplashKey"),
        "width": width if width >= 1280 else DEFAULT_WIDTH,
    }


class Failure(Exception):
    def __init__(self, reason, note=""):
        super().__init__(note)
        self.reason = reason
        self.note = note


def call(url, headers=None):
    headers = headers or {}
    headers.setdefault("User-Agent", AGENT)
    headers.setdefault("Accept", "application/json")
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            raw = response.read()
            return json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError as error:
        reason = "auth" if error.code in (401, 403) else "provider"
        raise Failure(reason, f"{error.code} from {url.split('?')[0]}") from error
    except (urllib.error.URLError, ValueError, OSError) as error:
        raise Failure("network", str(error)) from error


def photo(identifier, url, thumb, artist, link, description="", extension="jpg"):
    """One photograph as a job: the shell fetches it, never this process."""
    return {
        "id": str(identifier or ""),
        "url": url,
        "thumb": thumb,
        "artist": artist or "",
        "link": link or "",
        "description": description or "",
        "extension": extension,
    }


# ── PROVIDERS ───────────────────────────────────────────────────────────────
#
# Each takes the topic, a count, the page the shuffle landed on and the width,
# and answers with photos in the shape above. Keys are the shell's business:
# a provider that needs one refuses to be searched without it.

def wallhaven(key, topic, count, variation, width):
    # The minimum a wallpaper has to be is set by the width asked for, so a
    # narrow request does not hand back a phone screenshot.
    minimum = max(1920, min(width, 7680))
    endpoint = (
        f"{WALLHAVEN_SEARCH}?q={urllib.parse.quote(topic)}"
        f"&sort=toplist&order=desc&atleast={minimum}x{minimum * 9 // 16}"
        f"&categories=100&purity=100&page={variation + 1}"
    )
    report = call(endpoint)
    results = report.get("data") if isinstance(report, dict) else None
    if not isinstance(results, list):
        raise Failure("provider", "the answer was not a photo list")

    out = []
    for entry in results[:count]:
        if not isinstance(entry, dict):
            continue
        extension = "png" if str(entry.get("path", "")).endswith(".png") else "jpg"
        out.append(photo(
            entry.get("id"),
            entry.get("path"),
            entry.get("thumb"),
            entry.get("author") or entry.get("uploader") or "",
            f"https://wallhaven.cc/w/{entry.get('id')}",
            entry.get("shorturl") or entry.get("purity") or "",
            extension,
        ))
    return out


def unsplash(key, topic, count, variation, width):
    endpoint = (
        f"{UNSPLASH_SEARCH}?query={urllib.parse.quote(topic)}"
        f"&per_page={count}&page={variation + 1}"
        f"&orientation=landscape&content_filter=high"
    )
    report = call(endpoint, headers={"Authorization": f"Client-ID {key}"})
    results = report.get("results") if isinstance(report, dict) else None
    if not isinstance(results, list):
        raise Failure("provider", "the answer was not a photo list")

    out = []
    for entry in results:
        if not isinstance(entry, dict):
            continue
        urls = entry.get("urls") or {}
        raw = urls.get("raw") or urls.get("full") or ""
        # Imgix does the resizing; the original is only reached if a photo has
        # no raw URL at all, in which case `full` is as close as it gets.
        sized = (f"{raw}&q=90&w={width}&fm=jpg&fit=max"
                 if "?" in raw else f"{raw}&q=90&w={width}&fm=jpg" if raw else "")
        out.append(photo(
            entry.get("id"),
            sized or urls.get("full", ""),
            urls.get("small") or urls.get("regular") or "",
            ((entry.get("user") or {}).get("name") or ""),
            (entry.get("links") or {}).get("html") or "",
            entry.get("alt_description") or entry.get("description") or "",
        ))
    return out


def pexels(key, topic, count, variation, width):
    endpoint = (
        f"{PEXELS_SEARCH}?query={urllib.parse.quote(topic)}"
        f"&per_page={count}&page={variation + 1}&orientation=landscape&size=large"
    )
    report = call(endpoint, headers={"Authorization": key})
    results = report.get("photos") if isinstance(report, dict) else None
    if not isinstance(results, list):
        raise Failure("provider", "the answer was not a photo list")

    out = []
    for entry in results:
        if not isinstance(entry, dict):
            continue
        source = entry.get("src") or {}
        original = source.get("original") or source.get("large2x") or ""
        # The original can be enormous; the 2× variant is the one most monitors
        # can actually use, so it wins when the original is past 4K.
        if entry.get("width", 0) > 7680 and source.get("large2x"):
            original = source["large2x"]
        out.append(photo(
            entry.get("id"),
            original,
            source.get("medium") or source.get("small") or "",
            entry.get("photographer") or "",
            entry.get("url") or "",
            entry.get("alt") or "",
        ))
    return out


def openverse(key, topic, count, variation, width):
    endpoint = (
        f"{OPENVVERSE_SEARCH}?q={urllib.parse.quote(topic)}"
        f"&size=large&aspect_ratio=wide&mature=false"
        f"&page={variation + 1}&page_size={count}"
    )
    report = call(endpoint)
    results = report.get("results") if isinstance(report, dict) else None
    if not isinstance(results, list):
        raise Failure("provider", "the answer was not a photo list")

    out = []
    for entry in results:
        if not isinstance(entry, dict):
            continue
        url = entry.get("url") or ""
        extension = str(entry.get("filetype") or "jpg").split("/")[-1]
        out.append(photo(
            entry.get("id"),
            url,
            entry.get("thumbnail") or entry.get("preview") or "",
            entry.get("creator") or "",
            entry.get("foreign_landing_url") or "",
            entry.get("title") or "",
            extension if extension.isalnum() else "jpg",
        ))
    return out


def picsum(key, topic, count, variation, width):
    # The list endpoint is stable; the topic and the variation only shift the
    # window, so the same topic repeats its set until either changes.
    seed = sum(ord(char) for char in topic)
    page = (seed + variation * 7) % 30 + 1
    report = call(f"{PICSUM_LIST}?page={page}&limit={count}")
    if not isinstance(report, list):
        raise Failure("provider", "the answer was not a photo list")

    height = max(1080, width * 9 // 16)
    out = []
    for entry in report:
        if not isinstance(entry, dict) or entry.get("id") is None:
            continue
        out.append(photo(
            entry.get("id"),
            f"https://picsum.photos/id/{entry.get('id')}/{width}/{height}",
            f"https://picsum.photos/id/{entry.get('id')}/480/270",
            entry.get("author") or "",
            entry.get("url") or "",
        ))
    return out


# id → (function, needs a key, whether a topic is searched or the set is fixed)
CATALOGUE = {
    "wallhaven": (wallhaven, False, True),
    "unsplash": (unsplash, True, True),
    "pexels": (pexels, True, True),
    "openverse": (openverse, False, True),
    "picsum": (picsum, False, False),
}

LABELS = {
    "wallhaven": "Wallhaven",
    "unsplash": "Unsplash",
    "pexels": "Pexels",
    "openverse": "Openverse",
    "picsum": "Picsum",
}

NOTES = {
    "wallhaven": "4K first, no account needed",
    "unsplash": "photographs, needs an access key",
    "pexels": "photographs, needs an API key",
    "openverse": "openly licensed, across sources",
    "picsum": "a curated set, not searched",
}


def describe(config):
    """What can be searched from here, and what is ready to search."""
    out = []
    for identifier, (_, needs_key, searched) in CATALOGUE.items():
        ready = bool(config["key"]) or not needs_key
        out.append({
            "id": identifier,
            "label": LABELS[identifier],
            "note": NOTES[identifier],
            "searched": searched,
            "needsKey": needs_key,
            "available": ready,
        })
    return {
        "available": True,
        "provider": config["provider"],
        "width": config["width"],
        "providers": out,
    }


def run(command, arguments):
    config = settings()

    if command == "providers":
        return describe(config)
    if command != "search":
        raise Failure("input", f"unknown command: {command}")

    count = 24
    if arguments and arguments[0].isdigit():
        count = max(1, min(30, int(arguments[0])))
    variation = 0
    if len(arguments) > 1 and arguments[1].isdigit():
        variation = int(arguments[1])

    provider = config["provider"]
    entry = CATALOGUE.get(provider)
    if entry is None:
        raise Failure("input", f"unknown provider: {provider}")
    handler, needs_key, _ = entry
    if needs_key and not config["key"]:
        raise Failure("setup", f"{LABELS[provider]} needs a key")

    topic = config["topic"] or "nature"
    photos = handler(config["key"], topic, count, variation, config["width"])
    # Nothing the provider could offer at this size is said plainly rather
    # than left as an empty gallery.
    if not photos:
        raise Failure("provider", f"no photographs for “{topic}” at {config['width']}px")
    return {"available": True, "provider": provider, "topic": topic,
            "width": config["width"], "photos": photos}


def main():
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) > 1 else "search",
                             sys.argv[2:])))
    except Failure as failure:
        if failure.note:
            print(f"wallpaper-feed: {failure.reason}: {failure.note}",
                  file=sys.stderr)
        print(json.dumps({"available": False, "reason": failure.reason}))
        sys.exit(0)


if __name__ == "__main__":
    main()
