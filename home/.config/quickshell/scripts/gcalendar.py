#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   G C A L E N D A R                                                      │
# │   events from Google Calendar · oauth, refresh and read                  │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Google Calendar, reduced to what the shell needs.

The client id and secret come from the shell's own `settings.json` (Settings
→ Integrations); the refresh token never goes there. `connect` runs the
installed-app flow over a loopback port, opens the browser and keeps what
comes back in its own state file, user-only, on this machine — so a profile
switch never carries the key and the shell's settings file stays read-only
to this script.

Commands:

    connect        the one-time browser flow; writes the refresh token
    disconnect     forgets the token (and asks Google to revoke it)
    events         the next few weeks, single events, soonest first

Every command writes one JSON object to stdout; a failure is reported as
`{"available": false, "reason": ...}` rather than a traceback, so the shell
can keep its last good state.
"""

import base64
import hashlib
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

TIMEOUT = 15
STATE = "gcalendar.json"

CLIENTS = "https://oauth2.googleapis.com/token"
AUTHORIZE = "https://accounts.google.com/o/oauth2/v2/auth"
API = "https://www.googleapis.com/calendar/v3"
SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
# Google's installed-app clients accept any loopback port, per RFC 8252, so
# the redirect needs nothing registered on the Google side.
PORT = 16531
AUTH_BUDGET = 300
DAYS_BACK = 7
DAYS_AHEAD = 21
MAX_EVENTS = 250

ZERO_DATE = "0001-01-01"


class Failure(Exception):
    def __init__(self, reason, note=""):
        super().__init__(note)
        self.reason = reason
        self.note = note


def state_path():
    return os.path.join(
        os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
        "quickshell", STATE)


def state_directory():
    return os.path.dirname(state_path())


def settings():
    """The client id, secret and calendar id from the shell's settings."""
    path = os.path.join(
        os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
        "quickshell", "settings.json")
    try:
        with open(path, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        return "", "", "primary"
    client = str(stored.get("gcalClientId") or "").strip()
    secret = str(stored.get("gcalClientSecret") or "").strip()
    calendar = str(stored.get("gcalCalendar") or "primary").strip() or "primary"
    return client, secret, calendar


def read_token():
    try:
        with open(state_path(), encoding="utf-8") as handle:
            stored = json.load(handle)
        token = str(stored.get("refreshToken") or "").strip()
        return token
    except (OSError, ValueError):
        return ""


def write_token(token):
    os.makedirs(state_directory(), exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    # User-only from birth, so the token is never readable on the way past.
    descriptor = os.open(state_path(), flags, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        json.dump({"refreshToken": token, "created": datetime.now().isoformat()},
                  handle)
        handle.write("\n")


def drop_token():
    try:
        os.unlink(state_path())
    except OSError:
        pass


def post_form(body):
    """One form POST; `Failure` carries a shell-readable reason."""
    request = urllib.request.Request(
        CLIENTS, data=urllib.parse.urlencode(body).encode("utf-8"),
        headers={"Content-Type": "application/x-www-form-urlencoded",
                 "User-Agent": "impasto"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        detail = ""
        try:
            detail = json.loads(error.read()).get("error_description") or ""
        except Exception:
            pass
        # An expired or revoked refresh token means: connect again.
        raise Failure("auth", f"{error.code} {detail}") from error
    except urllib.error.URLError as error:
        raise Failure("network", str(error.reason)) from error
    except (ValueError, OSError) as error:
        raise Failure("network", str(error)) from error


def refresh_access(client, secret, token):
    answer = post_form({
        "client_id": client, "client_secret": secret, "refresh_token": token,
        "grant_type": "refresh_token",
    })
    access = str(answer.get("access_token") or "")
    if not access:
        raise Failure("auth", "no access token came back")
    return access


# ── CONNECT ─────────────────────────────────────────────────────────────────

class _Callback(BaseHTTPRequestHandler):
    code = None
    error = None

    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        _Callback.code = (query.get("code") or [None])[0]
        _Callback.error = (query.get("error") or [None])[0]
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(
            b"<html><body style='font-family:sans-serif;background:#111;"
            b"color:#eee;display:grid;place-items:center;height:100%'>"
            b"<p>Impasto has the key. You can close this tab.</p></body></html>")

    def log_message(self, *args):
        pass


def wait_for_code():
    handler = _Callback
    server = HTTPServer(("127.0.0.1", PORT), handler)
    deadline = time.monotonic() + AUTH_BUDGET
    while handler.code is None and handler.error is None:
        server.timeout = max(1, deadline - time.monotonic())
        if time.monotonic() >= deadline:
            break
        server.handle_request()
    server.server_close()
    if handler.code:
        return handler.code
    if handler.error:
        raise Failure("connect", f"the browser said: {handler.error}")
    raise Failure("connect", "no answer came back in five minutes")


def authorize(client, secret):
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    redirect = f"http://127.0.0.1:{PORT}"
    params = urllib.parse.urlencode({
        "client_id": client, "redirect_uri": redirect, "response_type": "code",
        "scope": SCOPE, "access_type": "offline", "prompt": "consent",
        "code_challenge": challenge, "code_challenge_method": "S256",
    })
    url = f"{AUTHORIZE}?{params}"
    # The URL goes to the log either way; the browser is a convenience.
    print(url, file=sys.stderr)
    try:
        subprocess.Popen(["xdg-open", url],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass
    code = wait_for_code()
    answer = post_form({
        "client_id": client, "client_secret": secret, "code": code,
        "code_verifier": verifier, "grant_type": "authorization_code",
        "redirect_uri": redirect,
    })
    token = str(answer.get("refresh_token") or "")
    if not token:
        raise Failure("connect", "no refresh token came back")
    write_token(token)


def revoke(token):
    request = urllib.request.Request(
        "https://oauth2.googleapis.com/revoke",
        data=urllib.parse.urlencode({"token": token}).encode("utf-8"),
        headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        urllib.request.urlopen(request, timeout=TIMEOUT).read()
    except (urllib.error.URLError, OSError):
        pass  # a dead token is as good as a revoked one


# ── EVENTS ──────────────────────────────────────────────────────────────────

def call_api(access, calendar, query):
    endpoint = (f"{API}/calendars/{urllib.parse.quote(calendar, safe='')}"
                f"/events?{urllib.parse.urlencode(query)}")
    request = urllib.request.Request(
        endpoint, headers={"Authorization": f"Bearer {access}",
                           "Accept": "application/json",
                           "User-Agent": "impasto"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        reason = "auth" if error.code in (401, 403) else "url"
        raise Failure(reason, f"{error.code} from the calendar") from error
    except urllib.error.URLError as error:
        raise Failure("network", str(error.reason)) from error
    except (ValueError, OSError) as error:
        raise Failure("network", str(error)) from error


def local(moment):
    """A moment the calendar wrote, in this machine's time. `dateTime` rides
    with an offset; `date` is already a plain day."""
    if not moment:
        return None, ""
    if "dateTime" in moment:
        try:
            when = datetime.fromisoformat(
                moment["dateTime"].replace("Z", "+00:00"))
        except ValueError:
            return None, ""
        return when.astimezone(), ""
    day = str(moment.get("date") or "")[:10]
    if not day or day.startswith(ZERO_DATE):
        return None, ""
    try:
        return datetime.fromisoformat(day), "allDay"
    except ValueError:
        return None, ""


def reduce_event(raw):
    start, start_kind = local(raw.get("start"))
    end, _ = local(raw.get("end"))
    if start is None:
        return None
    return {
        "id": raw.get("id") or "",
        "title": raw.get("summary") or "",
        "location": raw.get("location") or "",
        "day": start.strftime("%Y-%m-%d"),
        "endDay": end.strftime("%Y-%m-%d") if end else start.strftime("%Y-%m-%d"),
        "startTime": "" if start_kind == "allDay" else start.strftime("%H:%M"),
        "endTime": "" if start_kind == "allDay" or end is None else end.strftime("%H:%M"),
        "allDay": start_kind == "allDay",
    }


def events(client, secret, calendar):
    token = read_token()
    if not token:
        # Half a credential asks for the settings; a whole one without a
        # token asks for the browser. Different reasons, different clauses.
        return {"available": False, "reason": "connect", "connected": False}
    access = refresh_access(client, secret, token)
    now = datetime.now().astimezone()
    answer = call_api(access, calendar, {
        "timeMin": (now - timedelta(days=DAYS_BACK)).isoformat(timespec="seconds"),
        "timeMax": (now + timedelta(days=DAYS_AHEAD)).isoformat(timespec="seconds"),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": MAX_EVENTS,
    })
    out = []
    for raw in answer.get("items") or []:
        # A cancelled instance would otherwise keep its place on the day.
        if raw.get("status") in ("cancelled",):
            continue
        reduced = reduce_event(raw)
        if reduced:
            out.append(reduced)
    return {"available": True, "connected": True, "events": out}


# ── ENTRY ───────────────────────────────────────────────────────────────────

def run(command):
    client, secret, calendar = settings()
    if command == "connect":
        if not client or not secret:
            raise Failure("setup", "add the client id and secret first")
        authorize(client, secret)
        return {"available": True, "connected": True}

    if command == "disconnect":
        token = read_token()
        if token:
            revoke(token)
        drop_token()
        return {"available": True, "connected": False}

    if command == "events":
        if not client or not secret:
            return {"available": False, "reason": "setup", "connected": False}
        return events(client, secret, calendar)

    raise Failure("input", f"unknown command: {command}")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "events"
    try:
        print(json.dumps(run(command)))
    except Failure as error:
        sys.stderr.write(f"gcalendar: {error.reason}: {error.note}\n")
        print(json.dumps({"available": False, "reason": error.reason,
                          "connected": read_token() != ""}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"gcalendar failed: {error}\n")
        print(json.dumps({"available": False, "reason": "network",
                          "connected": read_token() != ""}))


if __name__ == "__main__":
    main()
