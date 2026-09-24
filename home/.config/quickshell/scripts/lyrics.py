#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   L Y R I C S                                                            │
# │   time-synced lyrics for the playing track · from lrclib                 │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Time-synced lyrics for one track, from LRCLIB (https://lrclib.net).

LRCLIB is a free, open lyrics library with no account and no key. Its API
takes what a player already knows — artist, track, album, length — which is
exactly what MPRIS hands the shell, so the same query works for YouTube Music
in a browser, Spotify or anything else on the bus.

The exact `/api/get` is tried first; when it misses, `/api/search` is asked
and the closest result by length (then by name) is taken. Only a line list is
returned, since that is all the widget draws. Any failure is reported as
unavailable, never as guessed lyrics.
"""

import json
import re
import subprocess
import sys
import urllib.parse

BASE = "https://lrclib.net/api"
# Identifies the client, as LRCLIB asks; a generic agent is rate-limited.
AGENT = "impasto-quickshell/1.0 (https://github.com/andreumassanet/impasto)"
TIMEOUT = 12

# `[mm:ss.xx]`, `[mm:ss.xxx]` or `[mm:ss]`, the timestamp in front of a line.
STAMP = re.compile(r"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]")
# Metadata tags (`[ar:…]`, `[offset:…]`) and rich-sync word stamps (`<…>`),
# which carry no lyric to show.
META = re.compile(r"^\[(ar|ti|al|by|re|ve|length|offset):", re.IGNORECASE)
WORD = re.compile(r"<[^>]*>")
# Bracketed tags a player may leave in a title: "(Official Video)", "[HD]".
NOISE = re.compile(r"[\(\[\{][^\)\]\}]*[\)\]\}]")


def request(path):
    result = subprocess.run(
        ["curl", "-sS", "--max-time", str(TIMEOUT), "-H", f"User-Agent: {AGENT}", path],
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(result.stderr.strip() or "no answer from lrclib")
    return json.loads(result.stdout)


def query(params):
    return f"{BASE}/{params}"


def stamp_ms(minutes, seconds, fraction):
    # Two-digit fractions are centiseconds, three are milliseconds.
    if fraction is None:
        millis = 0
    elif len(fraction) == 2:
        millis = int(fraction) * 10
    else:
        millis = int(fraction.ljust(3, "0")[:3])
    return int(minutes) * 60000 + int(seconds) * 1000 + millis


def parse_lrc(text):
    """LRC to `[(time_ms, line)]`, oldest first."""
    lines = []
    offset = 0
    for raw in text.splitlines():
        line = raw.strip()
        if line == "":
            continue
        if META.match(line):
            if line.lower().startswith("[offset:"):
                try:
                    offset = int(re.search(r"(-?\d+)", line).group(1))
                except (AttributeError, ValueError):
                    offset = 0
            continue
        stamps = list(STAMP.finditer(line))
        if not stamps:
            continue
        body = WORD.sub("", line[stamps[-1].end():]).strip()
        if body == "":
            continue
        for match in stamps:
            lines.append((stamp_ms(*match.groups()) + offset, body))
    lines.sort(key=lambda entry: entry[0])
    return [{"t": time, "text": body} for time, body in lines]


def similarity(candidate, track, artist):
    # Cheap exact-first ranking: a case-insensitive name match beats not.
    def same(field, wanted):
        return 1 if wanted and wanted.lower() in (field or "").lower() else 0

    return same(candidate.get("trackName"), track) + same(candidate.get("artistName"), artist)


def best(results, track, artist, duration):
    """The search result that best matches what is playing."""
    scored = []
    for index, entry in enumerate(results):
        if not entry.get("syncedLyrics"):
            continue
        # Unknown length sorts last rather than first.
        diff = abs((entry.get("duration") or 0) - duration) if duration > 0 else 0
        scored.append((diff, -similarity(entry, track, artist), index, entry))
    if not scored:
        return None
    scored.sort()
    return scored[0][3]


def report(track, artist, album, duration):
    duration = int(duration)
    exact = {
        "track_name": track,
        "artist_name": artist,
    }
    if album:
        exact["album_name"] = album
    if duration > 0:
        exact["duration"] = duration
    try:
        found = request(query("get?" + urllib.parse.urlencode(exact)))
        if found.get("syncedLyrics"):
            return package(found, track, artist)
    except Exception:
        pass

    # Fall back to a search; a title alone still usually lands.
    searched = []
    if track and artist:
        try:
            searched = request(query("search?" + urllib.parse.urlencode(
                {"track_name": track, "artist_name": artist})))
        except Exception:
            searched = []
    cleaned = NOISE.sub(" ", track).strip()
    broad = f"{cleaned} {artist}".strip()
    if not searched and broad:
        try:
            searched = request(query("search?" + urllib.parse.urlencode({"q": broad})))
        except Exception:
            searched = []
    # A last pass on the title alone, which is what a browser names a track
    # when its artist field is empty.
    if not searched and cleaned:
        try:
            searched = request(query("search?" + urllib.parse.urlencode({"q": cleaned})))
        except Exception:
            searched = []
    found = best(searched, track, artist, duration)
    if found is None:
        return {"available": False}
    return package(found, track, artist)


def package(entry, track, artist):
    synced = parse_lrc(entry.get("syncedLyrics") or "")
    if not synced:
        return {"available": False}
    return {
        "available": True,
        "source": "lrclib",
        "track": entry.get("trackName") or track,
        "artist": entry.get("artistName") or artist,
        "duration": entry.get("duration") or 0,
        "synced": synced,
    }


if __name__ == "__main__":
    # track, artist, album, duration in seconds. Every argument is optional
    # but the first two; empty ones are dropped.
    argv = sys.argv[1:5]
    while len(argv) < 4:
        argv.append("")
    track, artist, album, duration = argv
    track, artist, album = track.strip(), artist.strip(), album.strip()
    if track == "" and artist == "":
        print(json.dumps({"available": False, "reason": "track"}))
        sys.exit(0)
    try:
        print(json.dumps(report(track, artist, album, duration or 0)))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"lyrics failed: {error}\n")
        print(json.dumps({"available": False}))
