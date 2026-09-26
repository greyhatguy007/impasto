#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   O B S I D I A N   K A N B A N                                          │
# │   the task board as a markdown file in an Obsidian vault                 │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""An Obsidian Kanban board, reduced to what the shell's board needs.

The vault folder and the board file are read from the shell's own
`settings.json` (Settings -> Integrations -> Tasks), never from the command
line. Every command writes one JSON object to stdout; a failure is reported as
`{"available": false, "reason": ...}` rather than a traceback, so the shell can
keep its last good state.

The format is the Kanban plugin's own: `kanban-plugin: board` in the
frontmatter, one `## Lane` per lane, one `- [ ]`/`- [x]` list item per card, a
card's details as lines indented under it, and the plugin's trailing
`%% kanban:settings %%` block. A card's shell key is kept in an invisible HTML
comment in its details, so a card written here is found again after Obsidian
has touched the file.

Commands:

    tasks                 the board's cards, mapped to the shell's states
    create <json>         a card, from a JSON object on the command line
    update <key> <json>   the fields named in the JSON object; also moves it
    move <key> <lane> <index>
    delete <key>
    selftest              parse/serialise round trips, for `./setup check`
"""

import hashlib
import json
import os
import re
import sys
import tempfile

# The three lanes the shell knows, in board order. A board it writes uses the
# `heading`; a board it reads matches any of the aliases, case-insensitively.
LANES = [
    {"id": "todo",  "heading": "To do",  "aliases": ["to do", "todo", "backlog"]},
    {"id": "doing", "heading": "Doing",  "aliases": ["doing", "in progress", "in-progress"]},
    {"id": "done",  "heading": "Done",   "aliases": ["done", "complete", "completed"]},
]

HEADING = re.compile(r"^##\s+(.*?)\s*$")
CARD = re.compile(r"^- \[([ xX])\]\s?(.*)$")
KEY = re.compile(r"^\s*<!--\s*impasto:([A-Za-z0-9_.-]+)\s*-->\s*$")
DUE = re.compile(r"@\{(\d{4}-\d{2}-\d{2})\}")
SETTINGS = re.compile(r"^%%\s*kanban:settings")

SKELETON = """---
kanban-plugin: board
---

## To do

## Doing

## Done
"""


class Failure(Exception):
    def __init__(self, reason, note=""):
        super().__init__(note)
        self.reason = reason
        self.note = note


# ── CONFIGURATION ───────────────────────────────────────────────────────────


def state_directory():
    return os.path.join(
        os.environ.get("XDG_STATE_HOME")
        or os.path.expanduser("~/.local/state"),
        "quickshell",
    )


def settings():
    """The vault folder and board file from the shell's settings file."""
    path = os.path.join(state_directory(), "settings.json")
    try:
        with open(path, encoding="utf-8") as handle:
            stored = json.load(handle)
    except (OSError, ValueError):
        return "", ""
    vault = str(stored.get("obsidianVaultPath") or "").strip()
    board = str(stored.get("obsidianBoardFile") or "").strip() or "Tasks.md"
    return vault, board


def expand(path):
    """`~` and `~/...` against $HOME."""
    home = os.path.expanduser("~")
    if path == "~":
        return home
    if path.startswith("~/"):
        return os.path.join(home, path[2:])
    return path


def board_path():
    """The board's absolute path, or '' when no vault is set."""
    vault, board = settings()
    vault = expand(vault).rstrip("/")
    if not vault:
        return ""
    board = expand(board)
    if os.path.isabs(board):
        return board
    return os.path.join(vault, board)


def lane_for(title):
    """The lane id a heading names, or '' when it is not one of the three."""
    wanted = (title or "").strip().lower()
    for lane in LANES:
        if wanted in lane["aliases"]:
            return lane["id"]
    return ""


def lane_heading(lane_id):
    for lane in LANES:
        if lane["id"] == lane_id:
            return lane["heading"]
    return ""


def synthetic_key(lane_id, text, due, ordinal):
    """A stable key for a card Obsidian added without one."""
    digest = hashlib.sha1(
        f"{lane_id}\x1f{text}\x1f{due}\x1f{ordinal}".encode("utf-8")
    ).hexdigest()
    return f"obs-{digest[:12]}"


# ── PARSING ─────────────────────────────────────────────────────────────────
#
# The file is kept as a tree so that anything this script does not understand
# survives a round trip: the frontmatter and the plugin's settings block are
# raw lines, and a lane whose heading is not one of the three is kept whole.
# Only the cards of the three known lanes are touched.


def is_indented(line):
    return line != "" and line[0] in " \t"


def is_blank(item):
    return item["kind"] == "raw" and all(line.strip() == "" for line in item["lines"])


def parse_document(text):
    lines = text.replace("\r\n", "\n").split("\n")
    trailing = False
    if lines and lines[-1] == "":
        lines = lines[:-1]
        trailing = True

    prefix = []
    lanes = []
    tail = []
    current = None
    known = False
    index = 0
    while index < len(lines):
        line = lines[index]

        if SETTINGS.match(line):
            # The plugin's settings block, and anything after it, is the tail;
            # it is never parsed as board content.
            tail = lines[index:]
            break

        heading = HEADING.match(line)
        if heading:
            current = {"id": lane_for(heading.group(1)), "title": heading.group(1),
                       "heading": line, "items": []}
            known = current["id"] != ""
            lanes.append(current)
            index += 1
            continue

        card = CARD.match(line) if current is not None and known else None
        if card is None:
            if current is None:
                prefix.append(line)
            else:
                _append_raw(current["items"], line)
            index += 1
            continue

        block = [line]
        index += 1
        while index < len(lines) and is_indented(lines[index]):
            block.append(lines[index])
            index += 1
        current["items"].append({"kind": "card", "card": _parse_card(block)})

    for lane in lanes:
        if lane["items"] or lane["id"] != "":
            _number_cards(lane)

    return {"prefix": prefix, "lanes": lanes, "tail": tail, "trailing": trailing}


def _append_raw(target, line):
    if target and target[-1]["kind"] == "raw":
        target[-1]["lines"].append(line)
    else:
        target.append({"kind": "raw", "lines": [line]})


def _parse_card(block):
    match = CARD.match(block[0])
    done = match.group(1).lower() == "x"
    raw = match.group(2)
    due = ""
    found = DUE.search(raw)
    if found:
        due = found.group(1)
        raw = raw[:found.start()] + raw[found.end():]
    text = raw.strip()

    key = ""
    body = []
    for following in block[1:]:
        mark = KEY.match(following)
        if mark and not key:
            key = mark.group(1)
            continue
        body.append(_unindent(following))
    return {"key": key, "text": text, "body": "\n".join(body).rstrip(),
            "due": due, "done": done}


def _unindent(line):
    if line.startswith("\t"):
        return line[1:]
    stripped = line.lstrip(" ")
    removed = len(line) - len(stripped)
    if removed == 0:
        return line
    return line[min(removed, 4):]


def _number_cards(lane):
    """Give every card a key and its rank within the lane."""
    seen = {}
    rank = 0
    for item in lane["items"]:
        if item["kind"] != "card":
            continue
        card = item["card"]
        card["rank"] = rank
        rank += 1
        if card["key"]:
            continue
        signature = (card["text"], card["due"])
        ordinal = seen.get(signature, 0)
        seen[signature] = ordinal + 1
        card["key"] = synthetic_key(lane["id"], card["text"], card["due"], ordinal)


# ── SERIALISING ─────────────────────────────────────────────────────────────


def render_card(card):
    mark = "x" if card.get("done") else " "
    line = f"- [{mark}] {card.get('text', '')}"
    if card.get("due"):
        line += f" @{{{card['due']}}}"
    out = [line]
    if card.get("key"):
        out.append(f"\t<!-- impasto:{card['key']} -->")
    body = card.get("body", "")
    if body != "":
        for entry in body.split("\n"):
            out.append("\t" + entry if entry != "" else "\t")
    return out


def serialise(document):
    lines = list(document["prefix"])
    for lane in document["lanes"]:
        lines.append(lane["heading"])
        body = []
        for item in lane["items"]:
            if item["kind"] == "raw":
                body.extend(item["lines"])
            else:
                body.extend(render_card(item["card"]))
        # A known lane is written with exactly the blank line the plugin puts
        # after the heading and before the next one. An unknown lane is left
        # as it was found, byte for byte.
        if lane["id"]:
            while body and body[0].strip() == "":
                body.pop(0)
            while body and body[-1].strip() == "":
                body.pop()
            body = [""] + body + [""] if body else [""]
        lines.extend(body)
    lines.extend(document["tail"])
    text = "\n".join(lines)
    return text + "\n" if document.get("trailing", True) else text


def cards_of(document):
    """Every parsed card, in board order, with its lane."""
    out = []
    for lane in document["lanes"]:
        for item in lane["items"]:
            if item["kind"] == "card":
                out.append((lane, item))
    return out


def find_card(document, key):
    for lane, item in cards_of(document):
        if item["card"]["key"] == key:
            return lane, item
    return None, None


def ensure_lane(document, lane_id):
    """The lane, created (empty) before the tail when missing."""
    for lane in document["lanes"]:
        if lane["id"] == lane_id:
            return lane
    heading = lane_heading(lane_id)
    lane = {"id": lane_id, "title": heading, "heading": f"## {heading}",
            "items": [{"kind": "raw", "lines": [""]}]}
    document["lanes"].append(lane)
    return lane


def card_index(lane, rank):
    """Where a card at `rank` among a lane's cards belongs."""
    seen = 0
    for position, item in enumerate(lane["items"]):
        if item["kind"] != "card":
            continue
        if seen == rank:
            return position
        seen += 1
    last = -1
    for position, item in enumerate(lane["items"]):
        if item["kind"] == "card":
            last = position
    if last >= 0:
        return last + 1
    # No cards yet: after the blank line the heading is followed by.
    position = 0
    while position < len(lane["items"]) and is_blank(lane["items"][position]):
        position += 1
    return position


def insert_card(lane, card, rank=None):
    if rank is None:
        rank = sum(1 for item in lane["items"] if item["kind"] == "card")
    lane["items"].insert(card_index(lane, rank), {"kind": "card", "card": card})


# ── READING AND WRITING ─────────────────────────────────────────────────────


def read_board(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read(), True
    except FileNotFoundError:
        return SKELETON, False
    except OSError as error:
        raise Failure("io", str(error)) from error


def write_board(path, text):
    """Beside, then renamed: a half-written board is never on disk."""
    directory = os.path.dirname(path) or "."
    try:
        os.makedirs(directory, exist_ok=True)
        handle, temporary = tempfile.mkstemp(dir=directory, prefix=".impasto-kanban-")
        try:
            with os.fdopen(handle, "w", encoding="utf-8") as out:
                out.write(text)
            os.replace(temporary, path)
        except BaseException:
            try:
                os.unlink(temporary)
            except OSError:
                pass
            raise
    except OSError as error:
        raise Failure("io", str(error)) from error


def reduce_task(card, lane):
    return {
        "key": card["key"],
        "text": card["text"],
        "body": card.get("body", ""),
        "state": lane["id"],
        "due": card.get("due", ""),
        "rank": card.get("rank", 0),
        "done": bool(card.get("done")),
    }


def payload_fields(payload):
    """The fields named in a JSON payload; absent ones are left untouched."""
    fields = {}
    if "text" in payload:
        fields["text"] = str(payload["text"])
    if "body" in payload:
        fields["body"] = str(payload["body"])
    if "due" in payload:
        fields["due"] = str(payload["due"] or "")[:10]
    if "done" in payload:
        fields["done"] = bool(payload["done"])
    return fields


def read_payload(arguments):
    text = arguments[0] if arguments else sys.stdin.read()
    try:
        payload = json.loads(text) if text.strip() else {}
    except ValueError as error:
        raise Failure("input", f"bad JSON: {error}") from error
    if not isinstance(payload, dict):
        raise Failure("input", "expected a JSON object")
    return payload


def lane_id_from(payload, default="todo"):
    lane = str(payload.get("lane") or payload.get("state") or default).strip()
    known = lane_for(lane)
    if known == "":
        for entry in LANES:
            if entry["id"] == lane:
                return lane
        raise Failure("input", f"unknown lane: {lane}")
    return known


# ── COMMANDS ────────────────────────────────────────────────────────────────


def run_tasks(path):
    text, exists = read_board(path)
    document = parse_document(text)
    tasks = []
    for lane in document["lanes"]:
        if lane["id"] == "":
            continue
        for item in lane["items"]:
            if item["kind"] == "card":
                tasks.append(reduce_task(item["card"], lane))
    return {"available": True, "complete": True, "exists": exists,
            "board": path, "tasks": tasks}


def run_create(path, payload):
    key = str(payload.get("key") or "").strip()
    if key == "":
        raise Failure("input", "a card needs a key")
    lane_id = lane_id_from(payload)
    text, _ = read_board(path)
    document = parse_document(text)
    lane = ensure_lane(document, lane_id)
    card = {"key": key, "text": str(payload.get("text") or ""),
            "body": str(payload.get("body") or ""),
            "due": str(payload.get("due") or "")[:10],
            "done": bool(payload.get("done")), "rank": 0}
    insert_card(lane, card)
    write_board(path, serialise(document))
    return {"available": True, "task": reduce_task(card, lane)}


def run_update(path, key, payload):
    text, _ = read_board(path)
    document = parse_document(text)
    lane, item = find_card(document, key)
    if item is None:
        raise Failure("missing", f"no card with key {key}")
    card = item["card"]
    card.update(payload_fields(payload))
    if "lane" in payload or "state" in payload or "index" in payload:
        target_id = lane_id_from(payload, lane["id"])
        rank = int(payload["index"]) if payload.get("index") is not None else None
        lane["items"].remove(item)
        target = ensure_lane(document, target_id)
        insert_card(target, card, rank)
        lane = target
    write_board(path, serialise(document))
    return {"available": True, "task": reduce_task(card, lane)}


def run_move(path, key, lane_id, index):
    text, _ = read_board(path)
    document = parse_document(text)
    lane, item = find_card(document, key)
    if item is None:
        raise Failure("missing", f"no card with key {key}")
    lane["items"].remove(item)
    target = ensure_lane(document, lane_id)
    insert_card(target, item["card"], index)
    write_board(path, serialise(document))
    return {"available": True, "task": reduce_task(item["card"], target)}


def run_delete(path, key):
    text, _ = read_board(path)
    document = parse_document(text)
    lane, item = find_card(document, key)
    if item is None:
        raise Failure("missing", f"no card with key {key}")
    lane["items"].remove(item)
    write_board(path, serialise(document))
    return {"available": True, "key": key}


def run(command, arguments):
    path = board_path()
    if path == "":
        return {"available": False, "reason": "setup"}

    if command == "tasks":
        return run_tasks(path)
    if command == "create":
        return run_create(path, read_payload(arguments))
    if command == "update":
        if not arguments:
            raise Failure("input", "an update needs a card key")
        return run_update(path, arguments[0], read_payload(arguments[1:]))
    if command == "move":
        if len(arguments) < 3:
            raise Failure("input", "a move needs a key, a lane and an index")
        return run_move(path, arguments[0], lane_id_from({"lane": arguments[1]}),
                        int(arguments[2]))
    if command == "delete":
        if not arguments:
            raise Failure("input", "a delete needs a card key")
        return run_delete(path, arguments[0])
    raise Failure("input", f"unknown command: {command}")


# ── SELFTEST ────────────────────────────────────────────────────────────────


def selftest():
    """Round trips the parser and every write, in a temporary vault."""
    source = """---
kanban-plugin: board
---

## To do

- [ ] Pay rent @{2026-10-01}
\t<!-- impasto:task-one -->
\tRent is due on the first.

## Unknown lane

- [x] Leave this exactly @{2026-01-01}

## Done

- [x] Old thing @{2025-12-01}
\t<!-- impasto:task-old -->


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
"""
    document = parse_document(source)
    cards = {item["card"]["key"]: (lane["id"], item["card"])
             for lane, item in cards_of(document)}
    assert set(cards) == {"task-one", "task-old"}, cards
    assert cards["task-one"][0] == "todo", cards["task-one"]
    assert cards["task-one"][1]["due"] == "2026-10-01", cards["task-one"]
    assert cards["task-one"][1]["body"] == "Rent is due on the first.", cards["task-one"]
    assert cards["task-old"][1]["done"] is True, cards["task-old"]
    assert "kanban:settings" in serialise(document)

    # An unknown lane survives a round trip exactly.
    again = serialise(document)
    assert "## Unknown lane" in again
    assert "- [x] Leave this exactly @{2026-01-01}" in again
    assert parse_document(again)["tail"][0].startswith("%% kanban:settings")

    # A card Obsidian added without a key is given a stable one.
    keyless = source.replace("\t<!-- impasto:task-one -->\n", "")
    keys = [item["card"]["key"] for _, item in cards_of(parse_document(keyless))]
    assert keys[0].startswith("obs-"), keys

    # Write commands against a real file in a throwaway vault.
    with tempfile.TemporaryDirectory() as vault:
        path = os.path.join(vault, "Tasks.md")

        made = run_create(path, {"key": "task-two", "text": "Write docs",
                                 "body": "A body", "due": "2026-11-01", "lane": "doing"})
        assert made["task"]["state"] == "doing", made
        assert made["task"]["due"] == "2026-11-01", made
        assert os.path.isfile(path)

        listed = run_tasks(path)["tasks"]
        assert [task["key"] for task in listed] == ["task-two"], listed

        moved = run_update(path, "task-two", {"text": "Write the docs",
                                              "done": True, "lane": "done", "index": 0})
        assert moved["task"]["state"] == "done", moved
        assert moved["task"]["done"] is True, moved

        run_delete(path, "task-two")
        assert run_tasks(path)["tasks"] == [], run_tasks(path)["tasks"]

        # Creating a card in a file that is not there writes the skeleton.
        fresh = os.path.join(vault, "nested", "Board.md")
        run_create(fresh, {"key": "task-three", "text": "Start", "lane": "todo"})
        with open(fresh, encoding="utf-8") as handle:
            written = handle.read()
        assert written.startswith("---\nkanban-plugin: board\n"), written
        assert "## Doing" in written and "## Done" in written

    return {"available": True, "test": "obsidian_kanban"}


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "tasks"
    try:
        if command == "selftest":
            print(json.dumps(selftest()))
        else:
            print(json.dumps(run(command, sys.argv[2:])))
    except Failure as error:
        sys.stderr.write(f"obsidian-kanban: {error.reason}: {error.note}\n")
        print(json.dumps({"available": False, "reason": error.reason}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"obsidian-kanban failed: {error}\n")
        print(json.dumps({"available": False, "reason": "io"}))


if __name__ == "__main__":
    main()
