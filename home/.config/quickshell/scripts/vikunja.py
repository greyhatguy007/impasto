#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   V I K U N J A                                                          │
# │   tasks from a self-hosted Vikunja server                                │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Vikunja's REST API, reduced to what the board needs.

The server URL and an API token are read from the shell's own
`settings.json` (Settings -> Integrations), never from the command line, so
the token is not visible in a process listing. Every command writes one JSON
object to stdout; a failure is reported as `{"available": false, "reason":
...}` rather than a traceback, so the shell can keep its last good state.

Commands:

    tasks                 every task the token can see, with projects
    projects              the projects, for the settings picker
    create <json>         a task, from a JSON object on stdin
    update <id> <json>    the fields named in the JSON object on stdin
    delete <id>

`due` fields are plain `YYYY-MM-DD` days between the shell and here; Vikunja
stores them as midnight UTC.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 15
PER_PAGE = 250

# Vikunja writes an unset date as Go's zero time.
ZERO_DATE = "0001-01-01"


def state_directory():
    return os.path.join(
        os.environ.get("XDG_STATE_HOME")
        or os.path.expanduser("~/.local/state"),
        "quickshell",
    )


def settings():
    """The URL, token and project id from the shell's settings file."""
    path = os.path.join(state_directory(), "settings.json")
    try:
        with open(path, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        return "", "", 0
    url = str(stored.get("vikunjaUrl") or "").strip().rstrip("/")
    token = str(stored.get("vikunjaToken") or "").strip()
    try:
        project = int(stored.get("vikunjaProject") or 0)
    except (TypeError, ValueError):
        project = 0
    return url, token, project


def day_of(value):
    """A `YYYY-MM-DD` day from Vikunja's timestamp, or '' when unset."""
    if not value or not isinstance(value, str):
        return ""
    if value.startswith(ZERO_DATE) or len(value) < 10:
        return ""
    return value[:10]


def stamp_of(value):
    if not value or not isinstance(value, str) or value.startswith(ZERO_DATE):
        return ""
    return value


def call(url, token, method, path, body=None, query=None):
    """One request; raises `Failure` with a shell-readable reason."""
    endpoint = f"{url}/api/v1{path}"
    if query:
        endpoint += "?" + urllib.parse.urlencode(query)
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "User-Agent": "impasto",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(endpoint, data=data, headers=headers,
                                     method=method)
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            raw = response.read()
            pages = response.headers.get("x-pagination-total-pages")
            parsed = json.loads(raw) if raw.strip() else None
            return parsed, int(pages) if pages else 1
    except urllib.error.HTTPError as error:
        reason = "auth" if error.code in (401, 403) else "url"
        raise Failure(reason, f"{error.code} from {path}") from error
    except urllib.error.URLError as error:
        raise Failure("network", str(error.reason)) from error
    except (ValueError, OSError) as error:
        raise Failure("network", str(error)) from error


class Failure(Exception):
    def __init__(self, reason, note=""):
        super().__init__(note)
        self.reason = reason
        self.note = note


def reduce_task(task):
    labels = task.get("labels") or []
    return {
        "id": task.get("id", 0),
        "title": task.get("title") or "",
        "description": task.get("description") or "",
        "done": bool(task.get("done")),
        "due": day_of(task.get("due_date")),
        "project": task.get("project_id") or 0,
        "labels": [label.get("title") or "" for label in labels],
        "priority": task.get("priority") or 0,
        "created": stamp_of(task.get("created")),
        "doneAt": stamp_of(task.get("done_at")),
    }


def reduce_project(project):
    return {
        "id": project.get("id", 0),
        "title": project.get("title") or "",
        "archived": bool(project.get("is_archived")),
    }


def projects(url, token):
    listed, _ = call(url, token, "GET", "/projects")
    return [reduce_project(project) for project in (listed or [])]


def tasks(url, token, project_id):
    """Every task, following pagination. `complete` says whether the list is
    the whole of it, so the shell only prunes gone tasks on a full read."""
    path = f"/projects/{project_id}/tasks" if project_id else "/tasks"
    listed = []
    page = 1
    while True:
        chunk, total_pages = call(url, token, "GET", path,
                                  query={"per_page": PER_PAGE, "page": page})
        if isinstance(chunk, list):
            listed.extend(chunk)
        if page >= total_pages or not isinstance(chunk, list) or not chunk:
            break
        page += 1
        if page > 40:  # a runaway server; stop rather than loop forever
            break
    return listed


def body_from(payload):
    """The fields the script accepts, mapped to Vikunja's names."""
    body = {}
    if "title" in payload:
        body["title"] = str(payload["title"])
    if "description" in payload:
        body["description"] = str(payload["description"])
    if "done" in payload:
        body["done"] = bool(payload["done"])
    if "due" in payload:
        day = str(payload["due"] or "")[:10]
        body["due_date"] = f"{day}T00:00:00Z" if day else "0001-01-01T00:00:00Z"
    return body


def choose_project(url, token, wanted):
    """The configured project, or the first one the token owns."""
    if wanted:
        return wanted
    found = [project for project in projects(url, token)
             if not project["archived"]]
    if not found:
        raise Failure("project", "no project to create the task in")
    return found[0]["id"]


def read_payload(arguments):
    # The shell passes the body as one argument (a single JSON string, so no
    # shell quoting is involved); a hand-run command may pipe it instead.
    text = arguments[0] if arguments else sys.stdin.read()
    try:
        payload = json.loads(text) if text.strip() else {}
    except ValueError as error:
        raise Failure("input", f"bad JSON: {error}") from error
    if not isinstance(payload, dict):
        raise Failure("input", "expected a JSON object")
    return payload


def run(command, arguments):
    url, token, project = settings()
    if not url or not token:
        return {"available": False, "reason": "setup"}

    if command == "projects":
        return {"available": True, "projects": projects(url, token)}

    if command == "tasks":
        return {
            "available": True,
            "complete": True,
            "tasks": [reduce_task(task)
                      for task in tasks(url, token, project)],
            "projects": projects(url, token),
        }

    if command == "create":
        body = body_from(read_payload(arguments))
        if not body.get("title"):
            raise Failure("input", "a task needs a title")
        target = choose_project(url, token, project)
        made, _ = call(url, token, "PUT", f"/projects/{target}/tasks", body=body)
        return {"available": True, "task": reduce_task(made or {})}

    if command == "update":
        if not arguments:
            raise Failure("input", "an update needs a task id")
        task_id = int(arguments[0])
        changes = body_from(read_payload(arguments[1:]))
        # Vikunja replaces the whole task, so read it back and write it again
        # with only these fields changed. A partial body would blank the rest.
        current, _ = call(url, token, "GET", f"/tasks/{task_id}")
        if not isinstance(current, dict):
            raise Failure("url", f"task {task_id} could not be read")
        current.update(changes)
        updated, _ = call(url, token, "POST", f"/tasks/{task_id}", body=current)
        return {"available": True, "task": reduce_task(updated or current)}

    if command == "delete":
        if not arguments:
            raise Failure("input", "a delete needs a task id")
        call(url, token, "DELETE", f"/tasks/{int(arguments[0])}")
        return {"available": True, "id": int(arguments[0])}

    raise Failure("input", f"unknown command: {command}")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "tasks"
    try:
        print(json.dumps(run(command, sys.argv[2:])))
    except Failure as error:
        # The settings page shows the reason; the shell keeps its last state.
        sys.stderr.write(f"vikunja: {error.reason}: {error.note}\n")
        print(json.dumps({"available": False, "reason": error.reason}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"vikunja failed: {error}\n")
        print(json.dumps({"available": False, "reason": "network"}))


if __name__ == "__main__":
    main()
