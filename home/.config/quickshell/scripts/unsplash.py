#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   U N S P L A S H                                                        │
# │   wallpapers from unsplash · picsum when there is no key                 │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Wallpaper providers for the gallery in Settings → Integrations.

With an Unsplash access key, the search API is asked for photos matching the
topic and both full-size and regular-size URLs come back. Without one, the
Picsum Photos API serves a random curated photograph — no key, no account —
and the topic only seeds its pick, so the same topic repeats the same set
until it is changed.

Every photo is handed to the shell as a job the shell fetches itself, with
the process' stdout kept for the JSON report. A failure is reported as
`{"available": false, "reason": ...}`, never a traceback, in the shape the
other integration scripts use.

Commands:

    search    photos for the topic, as a list of jobs
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 15
AGENT = "impasto-quickshell/1.0 (https://github.com/andreumassanet/impasto)"

UNSPLASH_SEARCH = "https://api.unsplash.com/search/photos"
PICSUM_LIST = "https://picsum.photos/v2/list"


def state_directory():
    return os.path.join(
        os.environ.get("XDG_STATE_HOME")
        or os.path.expanduser("~/.local/state"),
        "quickshell",
    )


def settings():
    """The key and topic from the shell's settings file."""
    path = os.path.join(state_directory(), "settings.json")
    try:
        with open(path, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        return "", ""
    key = str(stored.get("unsplashKey") or "").strip()
    query = str(stored.get("unsplashQuery") or "").strip()
    return key, query


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


def reduce_photo(photo):
    """One photo as a job: the shell fetches it, never this process. The
    raw URL is asked for a sized JPEG, so a wallpaper lands at a few
    megabytes rather than the full original."""
    urls = photo.get("urls") or {}
    raw = urls.get("raw") or urls.get("full") or ""
    sized = f"{raw}&q=80&w=2560&fm=jpg&fit=max" if "?" in raw else raw
    return {
        "id": str(photo.get("id") or ""),
        "url": sized,
        "thumb": urls.get("small") or urls.get("regular") or "",
        "artist": (photo.get("user") or {}).get("name") or "",
        "link": photo.get("links") or {},
        "description": photo.get("description") or photo.get("alt_description") or "",
    }


def unsplash(key, topic, count, variation):
    topic = topic or "nature"
    endpoint = (
        f"{UNSPLASH_SEARCH}?query={urllib.parse.quote(topic)}"
        f"&per_page={count}&page={variation + 1}"
        f"&orientation=landscape&content_filter=high"
    )
    report = call(endpoint, headers={"Authorization": f"Client-ID {key}"})
    results = report.get("results") if isinstance(report, dict) else None
    if not isinstance(results, list):
        raise Failure("provider", "the answer was not a photo list")
    return [reduce_photo(photo) for photo in results if isinstance(photo, dict)]


def picsum(topic, count, variation):
    # The list endpoint is stable; the topic and the variation only shift
    # the window, so the same topic repeats its set until either changes.
    seed = sum(ord(char) for char in (topic or "random"))
    page = (seed + variation * 7) % 30 + 1
    report = call(f"{PICSUM_LIST}?page={page}&limit={count}")
    if not isinstance(report, list):
        raise Failure("provider", "the answer was not a photo list")
    return [
        {
            "id": str(entry.get("id") or ""),
            "url": f"https://picsum.photos/id/{entry.get('id')}/2560/1440",
            "thumb": f"https://picsum.photos/id/{entry.get('id')}/320/200",
            "artist": entry.get("author") or "",
            "link": entry.get("url") or "",
            "description": "",
        }
        for entry in report
        if isinstance(entry, dict) and entry.get("id") is not None
    ]


def run(command, arguments):
    if command != "search":
        raise Failure("input", f"unknown command: {command}")
    key, topic = settings()
    count = 24
    if arguments and arguments[0].isdigit():
        count = max(1, min(30, int(arguments[0])))
    variation = 0
    if len(arguments) > 1 and arguments[1].isdigit():
        variation = int(arguments[1])
    if key:
        return {"available": True, "provider": "unsplash",
                "photos": unsplash(key, topic, count, variation)}
    return {"available": True, "provider": "picsum",
            "photos": picsum(topic, count, variation)}


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "search"
    try:
        print(json.dumps(run(command, sys.argv[2:])))
    except Failure as error:
        sys.stderr.write(f"unsplash: {error.reason}: {error.note}\n")
        print(json.dumps({"available": False, "reason": error.reason}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"unsplash failed: {error}\n")
        print(json.dumps({"available": False, "reason": "network"}))


if __name__ == "__main__":
    main()
