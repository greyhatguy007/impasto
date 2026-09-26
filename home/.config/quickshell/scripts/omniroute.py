#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   O M N I   R O U T E                                                    │
# │   the gateway's own numbers · usage, providers, models, health           │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""What an OmniRoute gateway knows about itself.

OmniRoute is an OpenAI-compatible proxy that sits in front of many providers
and routes to whichever answers. It also keeps a dashboard's worth of numbers
about the traffic it carries: what was spent, which provider served it, which
model carried it, how healthy each connection is and how much room the server
itself has. This reads those management routes and nothing else — the shell
never sends a model request to learn them.

The gateway's address and key come from the shell's own settings, and failing
that from pi's provider entry, which is the answer on a desk where the gateway
is only ever pi's. A gateway that is not there is one quiet `available: false`
with a reason, never a traceback, so the shell keeps its last good state.

Commands:

    report      everything the gateway can say, in one JSON object
    test        the same ask, cut down to whether the gateway answered

Every command writes one JSON object to stdout.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
STATE = Path(
    os.environ.get("XDG_STATE_HOME") or (HOME / ".local" / "state")
) / "quickshell"

TIMEOUT = 15
USER_AGENT = "impasto"

# The routes worth asking for. Each is read on its own so one that this
# deployment does not speak cannot take the rest of the report with it.
ROUTES = (
    ("analytics", "/api/usage/analytics"),
    ("connections", "/api/providers"),
    ("callLogs", "/api/usage/call-logs?limit=16"),
    ("history", "/api/usage/history"),
    ("keys", "/api/keys"),
    ("health", "/api/monitoring/health"),
    ("storage", "/api/storage/health"),
    ("cache", "/api/cache/stats"),
    ("rateLimits", "/api/rate-limits"),
    ("tokenHealth", "/api/token-health"),
    ("telemetry", "/api/telemetry/summary"),
    ("resilience", "/api/resilience"),
    ("combos", "/api/combos"),
)


def fail(reason, note="", connected=True):
    """Report the gateway as unreadable, in the shell's shape."""
    if note:
        print(f"omniroute: {reason}: {note}", file=sys.stderr)
    print(json.dumps({"available": False, "reason": reason,
                      "connected": connected}))
    sys.exit(0)


# ── SETTINGS ────────────────────────────────────────────────────────────────

def settings():
    """The endpoint and the key, from the shell, or from pi's provider entry.

    A command-line override wins, so the settings pane can try an address
    before it is saved. Nothing is written back here.
    """
    path = STATE / "settings.json"
    try:
        with path.open() as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        stored = {}

    def value(name):
        for form in (f"--{name}", f"-{name[0]}"):
            if form in sys.argv:
                index = sys.argv.index(form)
                if index + 1 < len(sys.argv):
                    return sys.argv[index + 1].strip()
        return str(stored.get(name) or "").strip()

    endpoint = value("endpoint")
    key = value("key")
    if endpoint:
        base = endpoint.rstrip("/")
        return {"api": base, "root": base[:-3] if base.endswith("/v1") else base,
                "key": key}

    # pi's own provider entry, when the settings hold nothing: a gateway on
    # this desk is pi's by definition.
    try:
        models = json.loads((HOME / ".pi" / "agent" / "models.json").read_text())
        entry = (models.get("providers") or {}).get("omni") or {}
    except (OSError, ValueError, AttributeError):
        return None
    base = str(entry.get("baseUrl") or "").strip().rstrip("/")
    if not base:
        return None
    return {"api": base, "root": base[:-3] if base.endswith("/v1") else base,
            "key": str(entry.get("apiKey") or "").strip()}


# ── THE ASK ─────────────────────────────────────────────────────────────────

def get(server, route):
    """One management route, as JSON, or `None` when it will not answer.

    Returns `(payload, reason)`: a reason of `"unrouted"` (404), `"auth"`
    (401/403) or `"network"` is the shell's to draw, and a payload is the
    route's own object.
    """
    request = urllib.request.Request(
        f"{server['root']}{route}",
        headers={"Authorization": f"Bearer {server['key'] or 'omniroute-public'}",
                 "Accept": "application/json",
                 "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None, "unrouted"
        if error.code in (401, 403):
            return None, "auth"
        return None, "server"
    except (urllib.error.URLError, ValueError, OSError):
        return None, "network"
    try:
        return json.loads(body), None
    except (ValueError, TypeError):
        return None, "unrouted"


def number(value, default=0):
    """A number, or the default: the gateway sometimes sends strings."""
    if isinstance(value, bool) or value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def clean(value):
    """A JSON-safe copy: the report must never fail to serialise."""
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, dict):
        return {str(key): clean(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean(item) for item in value]
    return str(value)


# ── SHAPING ─────────────────────────────────────────────────────────────────
#
# The routes answer in the dashboard's own shape, in full. Each one is reduced
# here to the few fields the shell draws, so the widgets never learn a
# dashboard's field names — and so a version that renames a field cannot take
# a widget down with it.

def summary_of(analytics):
    source = (analytics or {}).get("summary") or {}
    return {
        "requests": int(number(source.get("totalRequests"))),
        "successful": int(number(source.get("successfulRequests"))),
        "successRate": number(source.get("successRatePct")),
        "promptTokens": int(number(source.get("promptTokens"))),
        "completionTokens": int(number(source.get("completionTokens"))),
        "tokens": int(number(source.get("totalTokens"))),
        "cost": round(number(source.get("totalCost")), 4),
        "latency": int(number(source.get("avgLatencyMs"))),
        "models": int(number(source.get("uniqueModels"))),
        "accounts": int(number(source.get("uniqueAccounts"))),
        "apiKeys": int(number(source.get("uniqueApiKeys"))),
        "coverage": number(source.get("requestedModelCoveragePct")),
        "streak": int(number(source.get("streak"))),
        "fallbackRate": number(source.get("fallbackRatePct")),
        "first": source.get("firstRequest"),
        "last": source.get("lastRequest"),
    }


def trend_of(analytics):
    rows = (analytics or {}).get("dailyTrend") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "date": str(row.get("date") or ""),
            "requests": int(number(row.get("requests"))),
            "tokens": int(number(row.get("totalTokens"))),
            "cost": round(number(row.get("cost")), 4),
        })
    return out


def models_of(analytics):
    rows = (analytics or {}).get("byModel") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "model": str(row.get("model") or ""),
            "provider": str(row.get("provider") or ""),
            "requests": int(number(row.get("requests"))),
            "promptTokens": int(number(row.get("promptTokens"))),
            "completionTokens": int(number(row.get("completionTokens"))),
            "tokens": int(number(row.get("totalTokens"))),
            "cost": round(number(row.get("cost")), 4),
            "latency": int(number(row.get("avgLatencyMs"))),
            "success": number(row.get("successRatePct")),
            "lastUsed": row.get("lastUsed"),
        })
    out.sort(key=lambda entry: (-entry["tokens"], entry["model"]))
    return out


def providers_of(analytics):
    rows = (analytics or {}).get("byProvider") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "provider": str(row.get("provider") or ""),
            "requests": int(number(row.get("requests"))),
            "tokens": int(number(row.get("totalTokens"))),
            "cost": round(number(row.get("cost")), 4),
            "latency": int(number(row.get("avgLatencyMs"))),
            "success": number(row.get("successRatePct")),
        })
    out.sort(key=lambda entry: (-entry["tokens"], entry["provider"]))
    return out


def accounts_of(analytics):
    rows = (analytics or {}).get("byAccount") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "account": str(row.get("account") or ""),
            "requests": int(number(row.get("requests"))),
            "tokens": int(number(row.get("totalTokens"))),
            "cost": round(number(row.get("cost")), 4),
            "latency": int(number(row.get("avgLatencyMs"))),
            "lastUsed": row.get("lastUsed"),
        })
    out.sort(key=lambda entry: (-entry["tokens"], entry["account"]))
    return out


def connections_of(payload):
    """The provider connections, with just the health a widget draws."""
    rows = (payload or {}).get("connections") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "id": str(row.get("id") or ""),
            "provider": str(row.get("provider") or ""),
            "name": str(row.get("name") or ""),
            "priority": int(number(row.get("priority"))),
            "active": row.get("isActive") is True,
            "status": str(row.get("testStatus") or "unknown"),
            "errorCode": row.get("errorCode"),
            "lastError": str(row.get("lastError") or ""),
            "lastErrorAt": row.get("lastErrorAt"),
            "backoff": int(number(row.get("backoffLevel"))),
            "proxy": row.get("proxyEnabled") is True,
            "protection": row.get("rateLimitProtection") is True,
        })
    out.sort(key=lambda entry: (entry["provider"], entry["name"]))
    return out


def health_of(payload):
    source = payload or {}
    memory = source.get("memoryUsage") or {}
    breakers = source.get("circuitBreakers") or {}
    providers = []
    for row in source.get("providerBreakers") or []:
        if not isinstance(row, dict):
            continue
        providers.append({
            "provider": str(row.get("provider") or ""),
            "state": str(row.get("state") or "").lower(),
            "failures": int(number(row.get("failureCount"))),
            "lastFailure": row.get("lastFailure"),
        })
    return {
        "status": str(source.get("status") or "unknown"),
        "version": str(source.get("version") or ""),
        "node": str((source.get("system") or {}).get("nodeVersion") or ""),
        "uptime": int(number(source.get("uptime"))),
        "connections": int(number(source.get("activeConnections"))),
        "memoryRss": int(number(memory.get("rss"))),
        "memoryHeap": int(number(memory.get("heapUsed"))),
        "breakerOpen": int(number(breakers.get("open"))),
        "breakerHalf": int(number(breakers.get("halfOpen"))),
        "breakerDegraded": int(number(breakers.get("degraded"))),
        "breakerClosed": int(number(breakers.get("closed"))),
        "breakers": providers,
    }


def storage_of(payload):
    source = payload or {}
    return {
        "driver": str(source.get("driver") or ""),
        "size": int(number(source.get("sizeBytes"))),
        "lastBackup": source.get("lastBackupAt"),
        "backups": int(number(source.get("backupCount"))),
    }


def cache_of(payload):
    source = payload or {}
    return {
        "size": int(number(source.get("size"))),
        "maxSize": int(number(source.get("maxSize"))),
        "bytes": int(number(source.get("bytes"))),
        "maxBytes": int(number(source.get("maxBytes"))),
        "hits": int(number(source.get("hits"))),
        "misses": int(number(source.get("misses"))),
        "hitRate": number(source.get("hitRate")),
    }


def rates_of(payload):
    out = []
    for row in (payload or {}).get("connections") or []:
        if not isinstance(row, dict):
            continue
        out.append({
            "connectionId": str(row.get("connectionId") or ""),
            "provider": str(row.get("provider") or ""),
            "name": str(row.get("name") or ""),
            "enabled": row.get("enabled") is True,
            "active": row.get("active") is True,
            "queued": int(number(row.get("queued"))),
            "running": int(number(row.get("running"))),
        })
    return out


def tokens_of(payload):
    source = payload or {}
    return {
        "total": int(number(source.get("total"))),
        "healthy": int(number(source.get("healthy"))),
        "errored": int(number(source.get("errored"))),
        "warning": int(number(source.get("warning"))),
        "status": str(source.get("status") or "unknown"),
    }


def telemetry_of(payload):
    source = payload or {}
    monitor = source.get("quotaMonitor") or {}
    return {
        "requests": int(number(source.get("totalRequests"))),
        "latency": int(number(source.get("avgLatencyMs"))),
        "p50": int(number(source.get("p50"))),
        "p95": int(number(source.get("p95"))),
        "p99": int(number(source.get("p99"))),
        "errorRate": number(source.get("errorRate")),
        "sessions": int(number((source.get("sessions") or {}).get("activeCount"))),
        "quotaActive": int(number(monitor.get("active"))),
        "quotaWarning": int(number(monitor.get("warning"))),
        "quotaExhausted": int(number(monitor.get("exhausted"))),
        "quotaErrors": int(number(monitor.get("errors"))),
    }


def combos_of(payload):
    out = []
    for row in (payload or {}).get("combos") or []:
        if not isinstance(row, dict):
            continue
        out.append({
            "name": str(row.get("name") or ""),
            "models": len(row.get("models") or []),
        })
    return out


def call_logs_of(payload):
    """The last few requests, as one row each.

    This is the gateway's own request log: when it ran, which model and
    provider served it, how long it took, what it cost in tokens, and the
    error when it failed. A status code and a duration per row is the closest
    thing to watching the router work.
    """
    out = []
    for row in payload or []:
        if not isinstance(row, dict):
            continue
        tokens = row.get("tokens") or {}
        out.append({
            "id": str(row.get("id") or ""),
            "time": row.get("timestamp"),
            "status": int(number(row.get("status"))),
            "model": str(row.get("model") or ""),
            "provider": str(row.get("provider") or ""),
            "account": str(row.get("account") or ""),
            "duration": int(number(row.get("duration"))),
            "input": int(number(tokens.get("in"))),
            "output": int(number(tokens.get("out"))),
            "compressed": int(number(tokens.get("compressed"))),
            "error": str(row.get("error") or "")[:220],
            "combo": str(row.get("comboName") or ""),
            "key": str(row.get("apiKeyName") or ""),
            "source": str(row.get("sourceFormat") or ""),
            "target": str(row.get("targetFormat") or ""),
        })
    return out


def history_of(payload):
    """Everything the gateway has ever served, summed."""
    source = payload or {}
    providers = source.get("byProvider") or {}
    return {
        "requests": int(number(source.get("totalRequests"))),
        "promptTokens": int(number(source.get("totalPromptTokens"))),
        "completionTokens": int(number(source.get("totalCompletionTokens"))),
        "cost": round(number(source.get("totalCost")), 4),
        "providers": len(providers) if isinstance(providers, dict) else 0,
    }


def keys_of(payload):
    """The gateway's issued keys, without the keys themselves."""
    out = []
    for row in (payload or {}).get("keys") or []:
        if not isinstance(row, dict):
            continue
        out.append({
            "name": str(row.get("name") or ""),
            "prefix": str(row.get("keyPrefix") or ""),
            "lastUsed": row.get("lastUsedAt"),
            "active": row.get("isActive") is True,
            "revoked": row.get("revokedAt") is not None,
            "scopes": [str(item) for item in row.get("scopes") or []],
            "models": len(row.get("allowedModels") or []),
            "limit": row.get("usageLimitEnabled") is True,
            "dailyLimit": row.get("dailyUsageLimitUsd"),
            "weeklyLimit": row.get("weeklyUsageLimitUsd"),
            "rpm": row.get("maxRequestsPerMinute"),
            "rpd": row.get("maxRequestsPerDay"),
            "banned": row.get("isBanned") is True,
        })
    return out


def resilience_of(payload):
    """How the gateway paces itself: the queue that smooths a burst."""
    source = (payload or {}).get("requestQueue") or {}
    return {
        "rpm": int(number(source.get("requestsPerMinute"))),
        "concurrent": int(number(source.get("concurrentRequests"))),
        "minGap": int(number(source.get("minTimeBetweenRequestsMs"))),
        "maxWait": int(number(source.get("maxWaitMs"))),
        "cooldown": (payload or {}).get("waitForCooldown", {}).get("enabled") is True,
    }


def tiers_of(analytics):
    """The service tiers the traffic ran in: standard, fast, flex."""
    rows = (analytics or {}).get("byServiceTier") or []
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        out.append({
            "tier": str(row.get("label") or row.get("serviceTier") or ""),
            "requests": int(number(row.get("requests"))),
            "tokens": int(number(row.get("totalTokens"))),
            "cost": round(number(row.get("cost")), 4),
            "savings": round(number(row.get("savings")), 4),
        })
    return out


def weekly_of(analytics):
    """The week, one row per weekday, for a small bar chart."""
    rows = (analytics or {}).get("weeklyPattern") or []
    counts = (analytics or {}).get("weeklyCounts") or []
    out = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        out.append({
            "day": str(row.get("day") or ""),
            "tokens": int(number(row.get("totalTokens"))),
            "requests": int(number(counts[index])) if index < len(counts)
                        else int(number(row.get("avgTokens"))),
        })
    return out


# ── THE REPORT ──────────────────────────────────────────────────────────────

def report(server, period):
    answer = {"available": True, "connected": True, "endpoint": server["root"],
              "period": period, "errors": {}}

    analytics, reason = get(server, f"/api/usage/analytics?period={period}")
    if analytics is None:
        # The analytics route is the one that matters: without it there is no
        # picture of the traffic, and the reason is worth passing on.
        if reason == "auth":
            return {"available": False, "connected": False, "reason": "auth"}
        if reason == "network":
            return {"available": False, "connected": False, "reason": "network"}
        return {"available": False, "connected": True, "reason": reason}

    answer["summary"] = summary_of(analytics)
    answer["trend"] = trend_of(analytics)
    answer["models"] = models_of(analytics)
    answer["byProvider"] = providers_of(analytics)
    answer["accounts"] = accounts_of(analytics)
    answer["tiers"] = tiers_of(analytics)
    answer["weekly"] = weekly_of(analytics)

    for key, route in ROUTES:
        if key == "analytics":
            continue
        payload, missed = get(server, route)
        if payload is None:
            answer["errors"][key] = missed
            answer[key] = empty_for(key)
            continue
        answer[key] = shape(key, payload)

    answer["fetchedAt"] = int(time.time())
    return clean(answer)


def empty_for(key):
    return {
        "connections": [], "callLogs": [], "history": history_of(None),
        "keys": [], "health": health_of(None), "storage": storage_of(None),
        "cache": cache_of(None), "rateLimits": [], "tokenHealth": tokens_of(None),
        "telemetry": telemetry_of(None), "resilience": resilience_of(None),
        "combos": [],
    }[key]


def shape(key, payload):
    if key == "connections":
        return connections_of(payload)
    if key == "callLogs":
        return call_logs_of(payload)
    if key == "history":
        return history_of(payload)
    if key == "keys":
        return keys_of(payload)
    if key == "health":
        return health_of(payload)
    if key == "storage":
        return storage_of(payload)
    if key == "cache":
        return cache_of(payload)
    if key == "rateLimits":
        return rates_of(payload)
    if key == "tokenHealth":
        return tokens_of(payload)
    if key == "telemetry":
        return telemetry_of(payload)
    if key == "resilience":
        return resilience_of(payload)
    if key == "combos":
        return combos_of(payload)
    return None


def test(server):
    """Whether the gateway answers at all, the version it runs, and a count."""
    payload, reason = get(server, "/api/monitoring/health")
    if payload is not None:
        health = health_of(payload)
        return {"available": True, "connected": True, "endpoint": server["root"],
                "version": health["version"], "status": health["status"]}
    if reason == "auth":
        return {"available": False, "connected": False, "reason": "auth"}
    if reason == "network":
        return {"available": False, "connected": False, "reason": "network"}
    # A server that does not route the management API is still a server if
    # the client API answers, which is what a models ask tells us.
    models, missed = get(server, "/api/v1/models")
    if models is not None:
        rows = models.get("data") if isinstance(models, dict) else None
        count = len(rows) if isinstance(rows, list) else 0
        return {"available": True, "connected": True, "endpoint": server["root"],
                "version": "", "status": "client-only", "models": count}
    return {"available": False, "connected": False,
            "reason": missed if missed else reason}


# ── ENTRY ───────────────────────────────────────────────────────────────────

def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "report"
    server = settings()
    if not server:
        fail("setup", "no endpoint configured", connected=False)

    if command == "report":
        period = "day"
        for known in ("day", "week", "month"):
            if f"--{known}" in sys.argv:
                period = known
        print(json.dumps(report(server, period)))
        return
    if command == "test":
        print(json.dumps(test(server)))
        return

    fail("input", f"unknown command: {command}", connected=False)


if __name__ == "__main__":
    main()
