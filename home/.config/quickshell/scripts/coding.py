#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O D I N G                                                            │
# │   a year of solved problems · leetcode or codeforces                     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""A rolling year of practice, from LeetCode or Codeforces.

LeetCode's public GraphQL answers a username with a submission calendar: a map
of UTC days to how many submissions landed on each. Codeforces has no calendar,
only the submission list, so accepted submissions are bucketed by day here.
Either way the shape is GitHub's — 53 columns of seven levels — so the same
contribution grid draws it.

The window run is the last 53 weeks ending today, aligned so every column is a
week. An empty or unknown name is reported as `"reason": "user"`; any other
failure as unavailable, never as guessed counts.
"""

import json
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone

AGENT = "impasto-quickshell/1.0 (https://github.com/andreumassanet/impasto)"
TIMEOUT = 15
WEEKS = 53

LEETCODE = "https://leetcode.com/graphql"
CALENDAR_QUERY = """
query userProfileCalendar($username: String!, $year: Int) {
  matchedUser(username: $username) {
    userCalendar(year: $year) {
      streak
      totalActiveDays
      submissionCalendar
    }
  }
}
"""
# Tried when the full query is refused, e.g. a field the schema has moved on
# from: `submissionCalendar` alone is the whole graph.
MINIMAL_QUERY = """
query userProfileCalendar($username: String!, $year: Int) {
  matchedUser(username: $username) {
    userCalendar(year: $year) { submissionCalendar }
  }
}
"""

CODEFORCES = "https://codeforces.com/api/user.status"


class UserNotFound(Exception):
    """The platform has no user under this name."""


def curl(args):
    result = subprocess.run(
        ["curl", "-sS", "--max-time", str(TIMEOUT), "-H", f"User-Agent: {AGENT}"] + args,
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(result.stderr.strip() or "no answer from the platform")
    return result.stdout


def level(count):
    if count <= 0:
        return 0
    if count <= 2:
        return 1
    if count <= 5:
        return 2
    if count <= 9:
        return 3
    return 4


def build_weeks(counts, today):
    """`counts` keyed by ISO date to a grid of 53 week-columns, Sunday first."""
    start = today - timedelta(days=WEEKS * 7 - 1)
    # Back to the Sunday that opens the first column.
    start -= timedelta(days=(start.weekday() + 1) % 7)
    columns = ((today - start).days // 7) + 1
    grid = [[None] * 7 for _ in range(columns)]
    day = start
    while day <= today:
        offset = (day - start).days
        grid[offset // 7][offset % 7] = level(counts.get(day.isoformat(), 0))
        day += timedelta(days=1)
    return grid, start


def stats(counts, start, today):
    window = [counts.get((start + timedelta(days=i)).isoformat(), 0)
              for i in range((today - start).days + 1)]
    # Today still counts as a live streak even before the first submission.
    streak = 0
    for index, count in enumerate(reversed(window)):
        if count > 0:
            streak += 1
        elif index == 0:
            continue
        else:
            break
    return {
        "total": sum(window),
        "streak": streak,
        "today": counts.get(today.isoformat(), 0),
        "busiest": max(window, default=0),
    }


def package(user, counts, today, source):
    grid, start = build_weeks(counts, today)
    report = {
        "available": True,
        "user": user,
        "source": source,
        "weeks": grid,
    }
    report.update(stats(counts, start, today))
    return report


# ── LEETCODE ────────────────────────────────────────────────────────────────

def leetcode_query(user, year, query):
    payload = json.dumps({
        "query": query,
        "variables": {"username": user, "year": year},
        "operationName": "userProfileCalendar",
    })
    body = curl(["-X", "POST", LEETCODE,
                 "-H", "Content-Type: application/json",
                 "-H", f"Referer: https://leetcode.com/{user}/",
                 "--data", payload])
    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"leetcode sent no json: {error}") from error


def leetcode_days(user, year):
    parsed = leetcode_query(user, year, CALENDAR_QUERY)
    matched = (parsed.get("data") or {}).get("matchedUser")
    if matched is None and parsed.get("errors"):
        # A field the schema no longer answers; ask for the graph alone.
        parsed = leetcode_query(user, year, MINIMAL_QUERY)
        matched = (parsed.get("data") or {}).get("matchedUser")
    if matched is None:
        raise UserNotFound(user)
    calendar = matched.get("userCalendar") or {}
    raw = calendar.get("submissionCalendar") or "{}"
    # A JSON string of `{ "<unix seconds>": count }`, at UTC midnight.
    try:
        stamps = json.loads(raw)
    except json.JSONDecodeError:
        stamps = {}
    counts = {}
    for stamp, count in stamps.items():
        day = datetime.fromtimestamp(int(stamp), tz=timezone.utc).date().isoformat()
        counts[day] = counts.get(day, 0) + int(count)
    return counts


def leetcode(user, today):
    # The tail of last year rides into the rolling window, so both years are
    # asked for and merged.
    counts = leetcode_days(user, today.year)
    counts.update(leetcode_days(user, today.year - 1))
    return package(user, counts, today, f"leetcode.com/{user}")


# ── CODEFORCES ──────────────────────────────────────────────────────────────

def codeforces(user, today):
    body = curl([f"{CODEFORCES}?handle={user}&from=1&count=10000"])
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"codeforces sent no json: {error}") from error
    if parsed.get("status") != "OK":
        comment = (parsed.get("comment") or "").lower()
        if "not found" in comment:
            raise UserNotFound(user)
        raise RuntimeError(parsed.get("comment") or "codeforces refused the request")
    counts = {}
    for submission in parsed.get("result") or []:
        if submission.get("verdict") != "OK":
            continue
        day = datetime.fromtimestamp(
            submission["creationTimeSeconds"], tz=timezone.utc).date().isoformat()
        counts[day] = counts.get(day, 0) + 1
    return package(user, counts, today, f"codeforces.com/profile/{user}")


# ── ENTRY ───────────────────────────────────────────────────────────────────

def report(platform, user):
    today = date.today()
    if platform == "codeforces":
        return codeforces(user, today)
    return leetcode(user, today)


if __name__ == "__main__":
    platform = (sys.argv[1] if len(sys.argv) > 1 else "leetcode").strip().lower()
    handle = " ".join(sys.argv[2:]).strip().lstrip("@")
    if handle == "":
        print(json.dumps({"available": False, "reason": "user"}))
        sys.exit(0)
    try:
        print(json.dumps(report(platform, handle)))
    except UserNotFound as error:
        sys.stderr.write(f"coding: no such user: {error}\n")
        print(json.dumps({"available": False, "reason": "user"}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"coding failed: {error}\n")
        print(json.dumps({"available": False}))
