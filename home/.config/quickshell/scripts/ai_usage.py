#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   A I   U S A G E                                                        │
# │   tokens spent in the current block and this week, any provider          │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Token usage for whatever agent the desk runs, in one report.

The shell does not care who is being talked to, only what was spent: every
provider is reduced to the same numbers — a five-hour block and the last
seven days, tokens in and out, messages, cost, and which models carried the
traffic — so one widget draws any of them and the setting that picks the
provider is one row in Settings → Integrations.

A provider is anything that keeps its usage on disk where the shell can read
it:

    claude      Claude Code's transcripts.
    pi          The pi agent's session logs — every provider it talks to.
    omniroute   The pi session logs filtered to the OmniRoute provider, and
                a health probe of the gateway from pi's own models.json.
    all         Every source above, added together.

Cache reads are reported but not counted against a budget: they re-send
context the provider has already seen. Transcripts only grow, so each file is
read from its last offset and the buckets are cached.

Commands:

    providers   what can be read on this machine
    usage       the block and the week for one provider, or the chosen one

Every command writes one JSON object to stdout; a failure is reported as
`{"available": false, "reason": ...}` rather than a traceback, so the shell
keeps its last good state.
"""

import calendar
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
STATE = Path(
    os.environ.get("XDG_STATE_HOME") or (HOME / ".local" / "state")
) / "quickshell"
CACHE = STATE / "ai-usage.json"

# The billing block, in hours. A block starts on the hour of its first
# message, the way a provider's own rolling window is described.
BLOCK_HOURS = 5
WEEK_HOURS = 24 * 7
TIMEOUT = 12

CACHE_VERSION = 2


def fail(reason, note="", connected=True):
    """Report the data as unavailable, in the shell's shape."""
    if note:
        print(f"ai-usage: {reason}: {note}", file=sys.stderr)
    print(json.dumps({"available": False, "reason": reason,
                      "connected": connected}))
    sys.exit(0)


# ── SETTINGS ────────────────────────────────────────────────────────────────

def settings():
    """The provider, the token ceilings and the paths, from the shell."""
    path = STATE / "settings.json"
    try:
        with path.open() as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        return {}, {}

    chosen = str(stored.get("aiProvider") or "all").strip() or "all"
    quotas = {
        "blockTokens": int(stored.get("aiBlockQuota") or 0),
        "weekTokens": int(stored.get("aiWeekQuota") or 0),
    }
    # Anything not asked for is left at the provider's own idea of where
    # its logs are, so a machine with the logs somewhere else can say so.
    overrides = {}
    for key, name in (("aiLogs", "claude"), ("aiPiLogs", "pi")):
        path = str(stored.get(key) or "").strip()
        if path:
            overrides[name] = Path(os.path.expanduser(path))
    return {"provider": chosen, "quota": quotas}, overrides


# ── THE CACHE ───────────────────────────────────────────────────────────────
#
# One entry per file, holding the byte offset to resume from and the hourly
# buckets already read out of it. A file that shrank was replaced rather than
# appended to, so it is read again from the start.

def load_cache():
    try:
        with CACHE.open() as handle:
            cache = json.load(handle)
        if cache.get("version") != CACHE_VERSION:
            return {"version": CACHE_VERSION, "files": {}}
        return cache
    except (OSError, ValueError):
        return {"version": CACHE_VERSION, "files": {}}


def save_cache(cache):
    # A month of history is more than the week and the peaks ever ask for;
    # past that the buckets are dropped so the file cannot grow forever.
    floor = int(time.time() // 3600) - 4 * 7 * 24
    day_floor = time.strftime("%Y%m%d", time.gmtime(time.time() - 7 * 86400))
    for files in cache.get("files", {}).values():
        for entry in files.values():
            entry["buckets"] = {
                hour: slot for hour, slot in entry.get("buckets", {}).items()
                if int(hour) >= floor}
            entry["models"] = {
                name: {day: model for day, model in by_day.items() if day >= day_floor}
                for name, by_day in entry.get("models", {}).items()}
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with CACHE.open("w") as handle:
            json.dump(cache, handle)
    except OSError as error:
        print(f"Cannot write the usage cache: {error}", file=sys.stderr)


def parse_timestamp(text):
    """A UTC ISO 8601 stamp as epoch seconds; timegm, never mktime."""
    if not text:
        return None
    try:
        return calendar.timegm(time.strptime(str(text)[:19], "%Y-%m-%dT%H:%M:%S"))
    except (TypeError, ValueError):
        return None


class Reader:
    """Walks a directory of JSONL transcripts, once each."""

    def __init__(self, provider, folder, cache):
        self.provider = provider
        self.folder = folder
        # Keyed by the reader, not the class: the two OmniRoute readers are
        # the same class over the same logs, told apart by their provider.
        self.files = cache.setdefault("files", {}).setdefault(provider.key, {})
        self.hours = {}

    def walk(self):
        if not self.folder.is_dir():
            return
        for path in sorted(self.folder.glob("**/*.jsonl")):
            entry = self.files.get(str(path), {})
            try:
                stat = path.stat()
                # A new turn on a live file shows up as a bigger mtime.
                if entry.get("mtime") == stat.st_mtime and entry.get("buckets"):
                    pass
                else:
                    entry = self.read(path, entry)
                    self.files[str(path)] = entry
            except OSError:
                continue
            for hour, slot in entry.get("buckets", {}).items():
                total = self.hours.setdefault(hour, self.provider.blank())
                for index, value in enumerate(slot):
                    total[index] = (total[index] if isinstance(total[index], (int, float))
                                    else 0) + value

    def read(self, path, entry):
        stat = path.stat()
        offset = entry.get("offset", 0)
        buckets = entry.get("buckets", {})
        models = entry.get("models", {})
        if stat.st_size < offset:
            offset, buckets, models = 0, {}, {}

        with path.open("r", errors="ignore") as handle:
            handle.seek(offset)
            for line in handle:
                # Cheap filter first: usage lives in one kind of record.
                if '"usage"' not in line:
                    continue
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                turn = self.provider.turn(record)
                if turn is None:
                    continue
                hour = str(int(turn["when"] // 3600))
                slot = buckets.setdefault(hour, [0, 0, 0, 0, 0, 0])
                for index, value in enumerate(turn["tokens"]):
                    slot[index] += value
                if turn["model"]:
                    # Kept by day, so the breakdown can be a week of traffic
                    # rather than everything the machine ever ran.
                    day = hour[:8]
                    entry_model = models.setdefault(turn["model"], {}).setdefault(
                        day, [0, 0, 0.0])
                    entry_model[0] += turn["tokens"][4]
                    entry_model[1] += 1
                    entry_model[2] = round(entry_model[2] + turn["cost"], 6)
            offset = handle.tell()

        return {"offset": offset, "mtime": stat.st_mtime,
                "buckets": buckets, "models": models}


# ── PROVIDERS ───────────────────────────────────────────────────────────────
#
# Each one knows where its usage is written and how to read a turn out of it.
# `tokens` is a fixed order every provider fills: input, output, cache write,
# cache read, all six together, and messages.

ORDER = ["input", "output", "cacheWrite", "cacheRead", "spent", "messages"]


class Provider:
    id = ""
    label = ""
    note = ""
    key = ""

    def blank(self):
        return [0] * len(ORDER)

    def turn(self, record):  # pragma: no cover - overridden
        return None

    @staticmethod
    def stamp(record):
        return parse_timestamp(record.get("timestamp"))


class ClaudeCode(Provider):
    """Claude Code's own transcripts, in `~/.claude/projects`."""

    id = "claude"
    label = "Claude Code"
    note = "the transcripts Claude Code writes"
    key = "claude"

    def turn(self, record):
        if record.get("type") != "assistant":
            return None
        usage = (record.get("message") or {}).get("usage") or {}
        when = self.stamp(record)
        if when is None or not usage:
            return None
        fresh = int(usage.get("input_tokens", 0) or 0)
        made = int(usage.get("cache_creation_input_tokens", 0) or 0)
        read = int(usage.get("cache_read_input_tokens", 0) or 0)
        out = int(usage.get("output_tokens", 0) or 0)
        # Cache reads are reported, not charged: they re-send context the
        # API has already seen, and would dwarf what was actually processed.
        spent = fresh + made + out
        return {"when": when, "model": (record.get("message") or {}).get("model", ""),
                "cost": 0.0,
                "tokens": [fresh, out, made, read, spent, 1]}


class PiSessions(Provider):
    """The pi agent's session logs, in `~/.pi/agent/sessions`.

    Every assistant turn carries the usage the provider returned, under
    pi's own field names, along with the provider and model that served it.
    `only` narrows it to one provider — the same logs, read for OmniRoute.
    """

    def __init__(self, only=None):
        self.only = only
        self.key = f"pi:{only}" if only else "pi"

    def turn(self, record):
        message = record.get("message")
        if not isinstance(message, dict):
            return None
        usage = message.get("usage")
        if not isinstance(usage, dict):
            return None
        when = self.stamp(record)
        if when is None:
            return None
        provider = str(message.get("provider") or "")
        if self.only is not None and provider != self.only:
            return None
        fresh = int(usage.get("input", 0) or 0)
        out = int(usage.get("output", 0) or 0)
        read = int(usage.get("cacheRead", 0) or 0)
        made = int(usage.get("cacheWrite", 0) or 0)
        cost = usage.get("cost")
        cost = float(cost.get("total", 0) or 0) if isinstance(cost, dict) else 0.0
        spent = fresh + out + made
        return {"when": when, "model": str(message.get("model") or ""),
                "cost": cost,
                "tokens": [fresh, out, made, read, spent, 1]}


# OmniRoute is pi's provider id for its own sessions, and `omniroute` is the
# one its manager writes; both are the same gateway.
OMNI_PROVIDERS = ["omni", "omniroute"]


def gateway():
    """OmniRoute's own reachability, from pi's provider entry.

    The gateway is OpenAI-compatible and speaks no usage API of its own, so
    the tokens come from the session logs; this says whether the desk is
    pointed at a gateway that answers, and how many models it offers.
    """
    entry = {}
    try:
        models = json.loads((HOME / ".pi" / "agent" / "models.json").read_text())
        entry = (models.get("providers") or {}).get("omni") or {}
    except (OSError, ValueError, AttributeError):
        return {"available": False, "reason": "setup", "models": 0}

    base = str(entry.get("baseUrl") or "").strip().rstrip("/")
    key = str(entry.get("apiKey") or "").strip()
    if not base:
        return {"available": False, "reason": "setup", "models": 0}

    request = urllib.request.Request(
        f"{base}/models",
        headers={"Authorization": f"Bearer {key or 'omniroute-public'}",
                 "User-Agent": "impasto"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            answer = json.loads(response.read() or b"{}")
        models = answer.get("data") if isinstance(answer, dict) else None
        return {"available": True, "models": len(models) if isinstance(models, list) else 0}
    except urllib.error.HTTPError as error:
        reason = "auth" if error.code in (401, 403) else "network"
        return {"available": False, "reason": reason, "models": 0}
    except (urllib.error.URLError, ValueError, OSError) as error:
        return {"available": False, "reason": "network", "note": str(error),
                "models": 0}


# ── THE REGISTRY ────────────────────────────────────────────────────────────

def sources(overrides):
    """Every reader the shell can offer, in the order they are listed."""
    claude = ClaudeCode()
    pi = PiSessions()
    omni = [PiSessions(only=name) for name in OMNI_PROVIDERS]
    return [
        {"id": "all", "label": "Everything", "note": "every source, added together",
         "readers": ([(claude, overrides.get("claude", HOME / ".claude" / "projects"))]
                     + [(pi, overrides.get("pi", HOME / ".pi" / "agent" / "sessions"))]),
         "gateway": False},
        {"id": "claude", "label": claude.label, "note": claude.note,
         "readers": [(claude, overrides.get("claude", HOME / ".claude" / "projects"))]},
        {"id": "pi", "label": "pi", "note": "every provider pi talks to",
         "readers": [(pi, overrides.get("pi", HOME / ".pi" / "agent" / "sessions"))],
         "gateway": False},
        {"id": "omniroute", "label": "OmniRoute", "note": "pi's OmniRoute provider",
         "readers": [(reader, HOME / ".pi" / "agent" / "sessions") for reader in omni],
         "gateway": True},
    ]


def source_for(identifier, overrides):
    for source in sources(overrides):
        if source["id"] == identifier:
            return source
    return None


# ── THE WINDOWS ─────────────────────────────────────────────────────────────

def windows(hours):
    """The block, the week and the busiest of each.

    A block runs from the hour of its first message, so the walk back from
    now stops as soon as it is out of reach of a five-hour window.
    """
    this_hour = int(time.time() // 3600)
    ordered = sorted(int(hour) for hour in hours)
    if not ordered:
        return None

    def total_over(first, last):
        out = [0] * len(ORDER)
        for hour in range(first, last + 1):
            slot = hours.get(str(hour))
            if slot:
                for index, value in enumerate(slot):
                    out[index] += value
        return out

    block_start = this_hour
    for hour in reversed(ordered):
        if hour > this_hour or hour <= this_hour - BLOCK_HOURS:
            continue
        block_start = min(block_start, hour)
    while block_start - 1 > this_hour - BLOCK_HOURS and str(block_start - 1) in hours:
        block_start -= 1

    first = min(ordered)
    last = max(ordered)
    peak_block = 0
    for hour in range(first, last + 1):
        peak_block = max(peak_block, total_over(hour, hour + BLOCK_HOURS - 1)[4])
    peak_week = 0
    for hour in range(first, last + 1, 12):
        peak_week = max(peak_week, total_over(hour, hour + WEEK_HOURS - 1)[4])

    return {
        "thisHour": this_hour,
        "blockStart": block_start * 3600,
        "blockEnd": (block_start + BLOCK_HOURS) * 3600,
        "block": total_over(block_start, this_hour),
        "week": total_over(this_hour - WEEK_HOURS + 1, this_hour),
        "peakBlockTokens": peak_block,
        "peakWeekTokens": peak_week,
    }


def usage(identifier, overrides, quota):
    """One provider's numbers, in the shell's shape."""
    source = source_for(identifier, overrides)
    if source is None:
        fail("input", f"unknown provider: {identifier}", connected=False)

    cache = load_cache()
    hours = {}
    days = {}
    for provider, folder in source["readers"]:
        reader = Reader(provider, folder, cache)
        reader.walk()
        for hour, slot in reader.hours.items():
            total = hours.setdefault(hour, [0] * len(ORDER))
            for index, value in enumerate(slot):
                total[index] += value
        for entry in reader.files.values():
            for name, by_day in entry.get("models", {}).items():
                seen = days.setdefault(name, {})
                for day, model in by_day.items():
                    total = seen.setdefault(day, [0, 0, 0.0])
                    for index, value in enumerate(model):
                        total[index] += value

    save_cache(cache)

    if not hours:
        # Nothing to draw: the reason says whether that is a missing folder
        # or a machine that simply has not used anything yet.
        missing = all(not folder.is_dir()
                      for _, folder in source["readers"])
        fail("setup" if missing else "empty",
             "no usage found in " + source["note"], connected=not missing)

    report = windows(hours)
    block, week = report.pop("block"), report.pop("week")

    # The week is what the per-model rows are about: a block is too short to
    # say which model a desk actually lives in. A day is kept when the week
    # covers it, so the breakdown is the same week the totals describe.
    floor = time.strftime("%Y%m%d", time.gmtime(time.time() - WEEK_HOURS * 3600))
    week_models = []
    for name, by_day in days.items():
        model = [0, 0, 0.0]
        for day, values in by_day.items():
            if day < floor:
                continue
            for index, value in enumerate(values):
                model[index] += value
        if model[0] > 0 or model[1] > 0:
            week_models.append({"id": name, "tokens": model[0],
                                "messages": model[1], "cost": round(model[2], 4)})
    week_models.sort(key=lambda row: (-row["tokens"], row["id"]))
    week_models = week_models[:8]

    answer = {
        "available": True,
        "connected": True,
        "provider": source["id"],
        "label": source["label"],
        "blockStart": report["blockStart"],
        "blockEnd": report["blockEnd"],
        "blockTokens": block[4],
        "blockMessages": block[5],
        "weekTokens": week[4],
        "weekMessages": week[5],
        "peakBlockTokens": report["peakBlockTokens"],
        "peakWeekTokens": report["peakWeekTokens"],
        "inputTokens": block[0],
        "outputTokens": block[1],
        "cacheWriteTokens": block[2],
        "cacheReadTokens": block[3],
        "weekInputTokens": week[0],
        "weekOutputTokens": week[1],
        "weekCacheWriteTokens": week[2],
        "weekCacheReadTokens": week[3],
        "cost": round(sum(model["cost"] for model in week_models), 4),
        "models": week_models,
        "quota": quota,
    }
    if source.get("gateway"):
        answer["gateway"] = gateway()
    return answer


def describe(overrides):
    """What each provider can be read from on this machine."""
    out = []
    for source in sources(overrides):
        folders = [folder for _, folder in source["readers"]]
        ready = any(folder.is_dir() for folder in folders)
        entry = {
            "available": ready,
            "id": source["id"],
            "label": source["label"],
            "note": source["note"],
            # Every folder it reads, because the aggregate reads more than
            # one and naming only the first would be half the answer.
            "paths": [str(folder) for _, folder in source["readers"]],
        }
        if source.get("gateway"):
            entry["gateway"] = gateway()
        out.append(entry)
    return {"available": True, "providers": out}


# ── ENTRY ───────────────────────────────────────────────────────────────────

def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "usage"
    chosen, overrides = settings()
    quota = chosen.get("quota", {"blockTokens": 0, "weekTokens": 0})

    if command == "providers":
        print(json.dumps(describe(overrides)))
        return
    if command == "usage":
        wanted = sys.argv[2] if sys.argv[2:3] and sys.argv[2] else chosen["provider"]
        print(json.dumps(usage(wanted, overrides, quota)))
        return

    fail("input", f"unknown command: {command}", connected=False)


if __name__ == "__main__":
    main()
