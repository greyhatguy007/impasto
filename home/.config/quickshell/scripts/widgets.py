#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   W I D G E T S                                                          │
# │   definitions · YAML in, a catalogue and a view model out                │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read the widget definitions and answer what the shell needs to draw them.

One YAML file per widget in `$XDG_CONFIG_HOME/quickshell/widgets/`. A
definition names the values it wants (from a command, a file or an HTTP
endpoint), keeps as much history as a chart asks for, and lays those values
out for each of the desktop's families and for the island's detail:

    id: cpu
    name: Processor
    sources:
      cpu: { command: [stats.py, once], every: 2s, parse: json,
             values: { load: cpu.total, temp: temperature.celsius } }
    history: { load: 120 }
    view:
      "2x2":
        - { kind: text, text: "{load:.0f}%", role: primary, size: 34 }
        - { kind: gauge, value: load, max: 100 }
      "4x2":
        - { kind: row, gap: 10, children: [
              { kind: text, text: "CPU", role: muted },
              { kind: bar, value: load, max: 100, grow: 1 },
              { kind: chart, value: load, span: 60 } ] }
    island:
      width: 356
      height: 150
      symbol: "\U000f035b"
      figure: "{load:.0f}%"
      detail: [ { kind: gauge, value: load, max: 100 } ]

Nothing here polls: `widgetd.py` runs the sources and prints one JSON line per
widget, and this module is what both it and the shell read to know what a
definition means. `widgets.py validate` is what `./setup check` runs, so a
typo in a definition is a line number rather than an empty widget.

Secrets are never written in a definition. `${secret:name}` reads the key
`name` from the shell's own settings, where every integration's token already
lives, and `${env:VAR}` reads the environment; both are resolved when a source
or an action is used, never in a view, so a secret cannot reach the shell as
part of a widget's text.
"""

import json
import os
import re
import shlex
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:      # a machine that has not run `./setup packages`
    yaml = None

# The desktop's four families, in the order the settings page lists them.
FAMILIES = ("2x2", "4x2", "4x4", "8x2")

# Ink a piece of a widget can draw in. `inkFor` resolves these, so a
# definition never names a colour and the wallpaper keeps its say; the last
# three are the shell's indicator colours, for a reading that is well or not.
ROLES = ("text", "muted", "accent", "accentText", "raised", "dim", "ground",
         "border", "good", "warn", "bad")

# What a definition can ask for. `every` is how often; a bare number is
# seconds. `parse` is how the answer is read; `path` (or `values`) is where
# the numbers are in it.
PARSERS = ("json", "text", "number", "bool", "lines", "csv", "regex")

# One definition's id: what `custom:<id>` is built from, so it has to survive
# a settings key and an element id.
ID = re.compile(r"[a-z][a-z0-9-]{0,31}")

# `{load}` and `{load:.0f}` in a template, and `{cpu.total}` for a path.
PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_.]*)(?::([^{}]*))?\}")

# `${secret:name}` or `${env:NAME}` anywhere in a source or an action.
SUBSTITUTION = re.compile(r"\$\{(secret|env):([A-Za-z_][A-Za-z0-9_]*)\}")

# Where the definitions are, and where a token like `${secret:name}` is read
# from — the shell's own settings file, written by Settings → Integrations.
FIELDS = ("kind", "grow", "width", "height", "align", "justify", "gap",
          "children", "text", "value", "values", "min", "max", "role", "span",
          "size", "bold", "mono", "wrap", "thickness", "rounded", "label",
          "style", "glyph", "svg", "image", "action", "confirm", "columns",
          "valign", "vertical")

KINDS = {
    # leaves
    "text":   {"text", "role", "size", "bold", "mono", "wrap", "align", "valign", "grow"},
    "bar":    {"value", "min", "max", "role", "thickness", "rounded", "label", "grow"},
    "gauge":  {"value", "min", "max", "role", "thickness", "label", "size", "grow"},
    "chart":  {"value", "min", "max", "role", "style", "span", "thickness", "grow"},
    "icon":   {"glyph", "svg", "image", "size", "role", "grow"},
    "button": {"action", "label", "glyph", "role", "size", "confirm", "align", "grow"},
    "spacer": {"grow"},
    "divider": {"role", "thickness", "vertical", "grow"},
    # containers
    "row":    {"children", "gap", "align", "justify", "grow"},
    "column": {"children", "gap", "align", "justify", "grow"},
    "grid":   {"children", "columns", "gap", "align", "grow"},
}

CONTAINERS = ("row", "column", "grid")

ALIGNMENTS = ("start", "center", "end", "fill")
JUSTIFICATIONS = ("start", "center", "end", "space-between", "space-around")
TEXT_ALIGNMENTS = ("left", "center", "right")
VALIGNMENTS = ("top", "center", "bottom")
CHART_STYLES = ("line", "area", "bars")

# A scheduled source: the intervals it can be asked for, and what it defaults
# to when nothing says. Slower than this would be indistinguishable from a
# notification, faster would be a busy loop on a shell that redraws anyway.
DEFAULT_EVERY = 5.0
MIN_EVERY = 0.25
MAX_EVERY = 24 * 3600.0

# How many samples a chart keeps when the definition does not say.
DEFAULT_KEEP = 60
MAX_KEEP = 3600


# ── PATHS ───────────────────────────────────────────────────────────────────


def config_dir() -> Path:
    """`$XDG_CONFIG_HOME`, or `~/.config`."""
    return Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))


def state_dir() -> Path:
    """`$XDG_STATE_HOME`, or `~/.local/state`. Where settings.json lives."""
    return Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local/state"))


def definitions_dir() -> Path:
    """Where the definitions are read from.

    `IMPASTO_WIDGETS` overrides it, which is how `./setup check` validates the
    ones in the repository rather than the ones installed in the home.
    """
    given = os.environ.get("IMPASTO_WIDGETS")
    return Path(given) if given else config_dir() / "quickshell" / "widgets"


def scripts_dir() -> Path:
    """The shell's own scripts, what a `command:` names without a directory."""
    return Path(__file__).resolve().parent


def settings_path() -> Path:
    return state_dir() / "quickshell" / "settings.json"


# ── SMALL TYPES ─────────────────────────────────────────────────────────────


class Invalid(Exception):
    """A definition that cannot be used; the message is shown to its owner."""

    def __init__(self, where: str, message: str):
        super().__init__(f"{where}: {message}")
        self.where = where
        self.message = message


def seconds(value, where: str) -> float:
    """`2s`, `500ms`, `1m`, `1h`, or a bare number of seconds."""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        out = float(value)
    elif isinstance(value, str):
        text = value.strip().lower()
        found = re.fullmatch(r"([0-9]*\.?[0-9]+)\s*(ms|s|m|h)?", text)
        if not found:
            raise Invalid(where, f"{value!r} is not an interval like 2s or 500ms")
        out = float(found.group(1)) * {"ms": 0.001, "s": 1.0, "m": 60.0,
                                      "h": 3600.0, None: 1.0}[found.group(2)]
    else:
        raise Invalid(where, "an interval is a number of seconds or a string like 2s")
    if not MIN_EVERY <= out <= MAX_EVERY:
        raise Invalid(where, f"{out:g}s is outside {MIN_EVERY:g}s–{MAX_EVERY:g}s")
    return out


def number(value, where: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise Invalid(where, f"{value!r} is not a number")
    return float(value)


def text(value, where: str) -> str:
    if not isinstance(value, str):
        raise Invalid(where, f"{value!r} is not a string")
    return value


def whole(value, where: str, low: int = 0, high: int = 1 << 20) -> int:
    found = number(value, where)
    if found != int(found) or not low <= found <= high:
        raise Invalid(where, f"{value!r} is not a whole number in {low}–{high}")
    return int(found)


def drill(data, path: str):
    """`cpu.total` or `disks[0].used` into a parsed answer."""
    at = data
    for step in re.findall(r"([^.[\]]+)|\[(\d+)\]", path):
        key, index = step
        try:
            if index != "":
                at = at[int(index)]
            else:
                at = at[key]
        except (KeyError, IndexError, TypeError):
            return None
    return at


# ── SECRETS ─────────────────────────────────────────────────────────────────
#
# A definition is a file somebody shares, so it holds no token: it names one.
# `${secret:name}` is a key of the shell's settings.json, where the tokens
# Settings → Integrations writes already live; `${env:NAME}` is the
# environment, for anything the shell should not keep at all.


def read_secrets() -> dict:
    try:
        return json.loads(settings_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def substitute(value, secrets=None):
    """Every `${secret:…}` and `${env:…}` in a string, list or map, resolved."""
    if isinstance(value, str):
        known = read_secrets() if secrets is None else secrets

        def swap(found):
            kind, name = found.group(1), found.group(2)
            if kind == "env":
                return os.environ.get(name, "")
            found_value = known.get(name)
            if found_value is None:
                raise Invalid("secrets", f"no {name!r} in the shell's settings")
            return str(found_value)

        return SUBSTITUTION.sub(swap, value)
    if isinstance(value, list):
        return [substitute(item, secrets) for item in value]
    if isinstance(value, dict):
        return {key: substitute(item, secrets) for key, item in value.items()}
    return value


def names_in(text_value: str) -> list:
    """The value names a template reaches for, e.g. `{load:.0f}` → `load`."""
    return [found.group(1) for found in PLACEHOLDER.finditer(text_value)]


# ── ELEMENTS ────────────────────────────────────────────────────────────────


def element(spec, where: str, produced: set, charted: set) -> dict:
    """One item of a view, checked and with its defaults filled in.

    `produced` is every value name the definition's sources answer, which is
    what a template or a `value:` is allowed to name — the check that turns a
    misspelled source into a message rather than a widget that reads blank.
    `charted` collects the names a chart draws, which are the ones that need
    samples kept even when the definition lists no history of its own.
    """
    if not isinstance(spec, dict):
        raise Invalid(where, "an element is a map, like { kind: text, text: \"…\" }")
    kind = spec.get("kind")
    if kind not in KINDS:
        raise Invalid(where, f"kind is {sorted(KINDS)}")
    allowed = KINDS[kind] | {"kind"}
    unknown = set(spec) - allowed
    if unknown:
        raise Invalid(where, f"{', '.join(sorted(unknown))} is not part of a {kind}")

    out = {"kind": kind}
    for field, value in spec.items():
        if field == "kind":
            continue
        out[field] = value

    def check_names(candidate, at: str):
        for name in names_in(candidate):
            if name.split(".")[0] not in produced:
                raise Invalid(at, f"{{{name}}} is not a value of this widget; "
                                  f"it answers {sorted(produced)}")

    if kind == "text":
        check_names(text(out.get("text", ""), where), f"{where}.text")
        if "role" in out and out["role"] not in ROLES:
            raise Invalid(f"{where}.role", f"role is one of {list(ROLES)}")
        if "align" in out and out["align"] not in TEXT_ALIGNMENTS:
            raise Invalid(f"{where}.align", f"align is one of {list(TEXT_ALIGNMENTS)}")
        if "valign" in out and out["valign"] not in VALIGNMENTS:
            raise Invalid(f"{where}.valign", f"valign is one of {list(VALIGNMENTS)}")
        for field in ("bold", "mono", "wrap"):
            if field in out and not isinstance(out[field], bool):
                raise Invalid(f"{where}.{field}", "true or false")
        out.setdefault("size", 0)
    elif kind in ("bar", "gauge", "chart"):
        if "value" not in out:
            raise Invalid(where, f"a {kind} needs a value, like value: load")
        value = out["value"]
        if isinstance(value, str):
            if value.split(".")[0] not in produced:
                raise Invalid(f"{where}.value", f"{value!r} is not a value of this "
                              f"widget; it answers {sorted(produced)}")
            if kind == "chart":
                charted.add(value.split(".")[0])
        else:
            out["value"] = number(value, f"{where}.value")
        out.setdefault("min", 0)
        out.setdefault("max", 100)
        if kind == "chart":
            out.setdefault("span", DEFAULT_KEEP)
            out.setdefault("style", "area")
            if out["style"] not in CHART_STYLES:
                raise Invalid(f"{where}.style", f"style is one of {list(CHART_STYLES)}")
        if kind in ("bar", "gauge"):
            out.setdefault("thickness", 8 if kind == "bar" else 10)
    elif kind == "icon":
        given = [field for field in ("glyph", "svg", "image") if field in out]
        if len(given) != 1:
            raise Invalid(where, "an icon is one of glyph, svg or image")
        out.setdefault("size", 0)
    elif kind == "button":
        text(out.get("action", ""), f"{where}.action")
        if not out["action"]:
            raise Invalid(where, "a button needs the name of an action")
        out.setdefault("label", "")
        # One or the other: a button that says nothing is a hole in the view,
        # and its action is not something to discover by pressing.
        if not out["label"] and not out.get("glyph"):
            raise Invalid(where, "a button needs a label or a glyph")
        out.setdefault("confirm", False)
        if not isinstance(out["confirm"], bool):
            raise Invalid(f"{where}.confirm", "true or false")
    elif kind == "divider":
        out.setdefault("thickness", 1)
        out.setdefault("vertical", False)

    if "role" in out and kind != "text" and out["role"] not in ROLES:
        raise Invalid(f"{where}.role", f"role is one of {list(ROLES)}")
    if "align" in out and kind in CONTAINERS and out["align"] not in ALIGNMENTS:
        raise Invalid(f"{where}.align", f"align is one of {list(ALIGNMENTS)}")
    if "justify" in out and out["justify"] not in JUSTIFICATIONS:
        raise Invalid(f"{where}.justify", f"justify is one of {list(JUSTIFICATIONS)}")
    if "gap" in out:
        out["gap"] = whole(out["gap"], f"{where}.gap", 0, 200)
    if "grow" in out:
        out["grow"] = number(out["grow"], f"{where}.grow")
    for field in ("width", "height", "size", "thickness", "columns"):
        if field in out and out[field] is not None:
            out[field] = whole(out[field], f"{where}.{field}", 0, 4000)

    if kind in CONTAINERS:
        children = out.get("children")
        if not isinstance(children, list) or not children:
            raise Invalid(where, "a container needs children")
        if kind == "grid":
            out.setdefault("columns", 2)
        for index, child in enumerate(children):
            children[index] = element(child, f"{where}.children[{index}]", produced, charted)

    return out


# ── DEFINITIONS ─────────────────────────────────────────────────────────────


def sources_of(spec, where: str) -> tuple:
    """The scheduled sources, and every value name they answer."""
    if not isinstance(spec, dict) or not spec:
        raise Invalid(where, "a widget needs at least one source")
    out = {}
    produced = []
    for name, source in spec.items():
        at = f"{where}.sources.{name}"
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", name):
            raise Invalid(f"{where}.sources", f"{name!r} is not a source name; a name "
                          "is letters, digits, _ and -")
        if not isinstance(source, dict):
            raise Invalid(at, "a source is a map, like { command: […], every: 2s }")
        given = [field for field in ("command", "file", "url") if field in source]
        if len(given) != 1:
            raise Invalid(at, "a source is one of command, file or url")
        unknown = set(source) - {"command", "file", "url", "method", "headers",
                                 "body", "every", "timeout", "parse", "path",
                                 "values", "pattern", "scale", "offset"}
        if unknown:
            raise Invalid(at, f"{', '.join(sorted(unknown))} is not part of a source")

        kept = dict(source)
        kept["every"] = seconds(source.get("every", DEFAULT_EVERY), f"{at}.every")
        parse = source.get("parse", "json" if "url" in source else "text")
        if parse not in PARSERS:
            raise Invalid(f"{at}.parse", f"parse is one of {list(PARSERS)}")
        kept["parse"] = parse
        kept["timeout"] = number(source.get("timeout", 10), f"{at}.timeout")
        if "command" in source:
            command = source["command"]
            if isinstance(command, str):
                command = shlex.split(command)
            if not isinstance(command, list) or not all(isinstance(part, str) for part in command):
                raise Invalid(f"{at}.command", "the command is a list of arguments")
            kept["command"] = command
        if "headers" in source and not isinstance(source["headers"], dict):
            raise Invalid(f"{at}.headers", "headers is a map of name to value")
        # A source-wide scale, which a value can override: one answer often
        # holds both a percentage and a byte count, and neither should need a
        # second run of the same command.
        default_scale = number(source.get("scale", 1), f"{at}.scale")
        default_offset = number(source.get("offset", 0), f"{at}.offset")
        if parse == "regex" and not source.get("pattern"):
            raise Invalid(at, "parse: regex needs a pattern")

        # What this source names. `values:` maps names to a path in the
        # answer; a single `path:` takes the source's own name; neither takes
        # the whole answer.
        readings = {}
        if "values" in source:
            if not isinstance(source["values"], dict) or not source["values"]:
                raise Invalid(f"{at}.values", "values maps names to paths")
            for key, path in source["values"].items():
                if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                    raise Invalid(f"{at}.values", f"{key!r} is not a value name; a name "
                                  "is letters, digits and _")
                readings[key] = reading(path, f"{at}.values.{key}",
                                        default_scale, default_offset)
        elif "path" in source:
            readings[name] = reading(source["path"], f"{at}.path",
                                     default_scale, default_offset)
        else:
            readings[name] = {"path": None, "scale": default_scale,
                              "offset": default_offset}
        kept["readings"] = readings
        produced.extend(readings)
        out[name] = kept
    return out, produced


def reading(spec, where: str, scale: float, offset: float) -> dict:
    """One value out of a source's answer, and its own scale.

    A path, or a map when the same answer mixes units: `{ path: memory.used,
    scale: 9.3e-10 }` reads bytes where `{ path: cpu.total }` reads a
    percentage, out of one run of the command.
    """
    if spec is None:
        return {"path": None, "scale": scale, "offset": offset}
    if isinstance(spec, str):
        return {"path": spec, "scale": scale, "offset": offset}
    if isinstance(spec, dict):
        unknown = set(spec) - {"path", "scale", "offset"}
        if unknown:
            raise Invalid(where, f"{', '.join(sorted(unknown))} is not part of a value")
        path = spec.get("path")
        return {"path": None if path is None else text(path, f"{where}.path"),
                "scale": number(spec.get("scale", scale), f"{where}.scale"),
                "offset": number(spec.get("offset", offset), f"{where}.offset")}
    raise Invalid(where, "a value is a path, or a map of path, scale and offset")


def definition(raw, where: str, fallback_id: str) -> tuple:
    """One definition, checked. Answers the catalogue entry and the view."""
    if not isinstance(raw, dict):
        raise Invalid(where, "a definition is a map of fields")
    unknown = set(raw) - {"id", "name", "enabled", "sources", "history", "view",
                          "island", "actions", "note"}
    if unknown:
        raise Invalid(where, f"{', '.join(sorted(unknown))} is not a field of a widget")

    name_id = raw.get("id", fallback_id)
    if not isinstance(name_id, str) or not ID.fullmatch(name_id):
        raise Invalid(f"{where}.id", "an id is lower-case letters, digits and -")

    sources, produced = sources_of(raw.get("sources"), f"{where}.sources")

    history = {}
    charted = set()
    given_history = raw.get("history") or {}
    if not isinstance(given_history, dict):
        raise Invalid(f"{where}.history", "history maps a value name to how many samples")
    for key, keep in given_history.items():
        at = f"{where}.history.{key}"
        if not isinstance(key, str):
            raise Invalid(at, f"{key!r} is not a value name")
        if isinstance(keep, dict):
            keep = keep.get("keep", DEFAULT_KEEP)
        history[key] = whole(keep, at, 1, MAX_KEEP)
        if key not in produced:
            raise Invalid(at, f"{key!r} is not a value of this widget; "
                              f"it answers {sorted(produced)}")

    # Charts keep their own history even when the definition does not list it,
    # since a chart with one sample is a dot.
    view = raw.get("view") or {}
    if not isinstance(view, dict) or not view:
        raise Invalid(where, "a widget needs a view, per family")
    families = []
    views = {}
    for family, items in view.items():
        at = f"{where}.view.{family}"
        if family not in FAMILIES:
            raise Invalid(at, f"a family is one of {list(FAMILIES)}")
        if not isinstance(items, list) or not items:
            raise Invalid(at, "a family's view is a list of elements")
        views[family] = [element(item, f"{at}[{index}]", set(produced), charted)
                         for index, item in enumerate(items)]
        families.append(family)
    families.sort(key=FAMILIES.index)

    # A chart with one sample is a dot, so whatever it draws keeps samples
    # even when the definition asked for no history: a text reading does not.
    for name in charted:
        history.setdefault(name, DEFAULT_KEEP)

    island = None
    given_island = raw.get("island")
    if given_island is not None:
        if not isinstance(given_island, dict):
            raise Invalid(f"{where}.island", "island is a map")
        unknown = set(given_island) - {"width", "height", "symbol", "figure", "detail"}
        if unknown:
            raise Invalid(f"{where}.island", f"{', '.join(sorted(unknown))} is not part "
                                             "of island")
        island = {
            "width": whole(given_island.get("width", 356), f"{where}.island.width", 80, 2000),
            "height": whole(given_island.get("height", 150), f"{where}.island.height", 40, 1200),
            "symbol": text(given_island.get("symbol", ""), f"{where}.island.symbol"),
            "figure": text(given_island.get("figure", ""), f"{where}.island.figure"),
        }
        if island["figure"]:
            for found in names_in(island["figure"]):
                if found.split(".")[0] not in produced:
                    raise Invalid(f"{where}.island.figure",
                                  f"{{{found}}} is not a value of this widget")
        detail = given_island.get("detail") or []
        if not isinstance(detail, list):
            raise Invalid(f"{where}.island.detail", "detail is a list of elements")
        island["detail"] = [element(item, f"{where}.island.detail[{index}]",
                                    set(produced), charted)
                            for index, item in enumerate(detail)]
        for name in charted:
            history.setdefault(name, DEFAULT_KEEP)

    actions = {}
    given_actions = raw.get("actions") or {}
    if not isinstance(given_actions, dict):
        raise Invalid(f"{where}.actions", "actions maps a name to what it does")
    for name, spec in given_actions.items():
        at = f"{where}.actions.{name}"
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", name):
            raise Invalid(f"{where}.actions", f"{name!r} is not an action name; a name "
                          "is letters, digits, _ and -")
        if not isinstance(spec, dict):
            raise Invalid(at, "an action is a map, like { url: …, method: POST }")
        given = [field for field in ("command", "url") if field in spec]
        if len(given) != 1:
            raise Invalid(at, "an action is one of command or url")
        unknown = set(spec) - {"command", "url", "method", "headers", "body", "json",
                               "timeout", "confirm", "shell"}
        if unknown:
            raise Invalid(at, f"{', '.join(sorted(unknown))} is not part of an action")
        out = dict(spec)
        out["timeout"] = number(spec.get("timeout", 10), f"{at}.timeout")
        if "command" in spec:
            command = spec["command"]
            if isinstance(command, str):
                command = shlex.split(command)
            if not isinstance(command, list) or not all(isinstance(part, str) for part in command):
                raise Invalid(f"{at}.command", "the command is a list of arguments")
            out["command"] = command
        if "json" in spec and "body" in spec:
            raise Invalid(at, "an action takes json or body, not both")
        actions[name] = out

    # Buttons may only name an action the definition declares.
    for family, items in views.items():
        for index, item in enumerate(items):
            for at, used in walk_buttons(item, f"{where}.view.{family}[{index}]"):
                if used not in actions:
                    raise Invalid(at, f"{used!r} is not an action of this widget; "
                                      f"it declares {sorted(actions) or 'none'}")
    if island:
        for index, item in enumerate(island["detail"]):
            for at, used in walk_buttons(item, f"{where}.island.detail[{index}]"):
                if used not in actions:
                    raise Invalid(at, f"{used!r} is not an action of this widget; "
                                      f"it declares {sorted(actions) or 'none'}")

    enabled = raw.get("enabled", True) is not False
    # The catalogue entry is what the shell reads: `id` is the module id it
    # places as a row, `widget` the definition behind it. The plan keeps the
    # definition's own name, which is what its file and its commands use.
    entry = {
        "id": f"custom:{name_id}",
        "name": text(raw.get("name", name_id), f"{where}.name"),
        "widget": name_id,
        "bar": island is not None and enabled,
        "desk": enabled,
        "enabled": enabled,
        "width": island["width"] if island else 0,
        "height": island["height"] if island else 0,
        "families": families,
        "views": views,
        "island": island,
        "note": text(raw.get("note", ""), f"{where}.note"),
    }
    return {"id": name_id, "path": where, "sources": sources,
            "history": history, "actions": actions, "catalogue": entry}


def walk_buttons(item, where: str):
    """Every button in an element and its children, with where it was written."""
    if item.get("kind") == "button":
        yield f"{where}.action", item["action"]
    for index, child in enumerate(item.get("children", [])):
        yield from walk_buttons(child, f"{where}.children[{index}]")


# ── LOADING ─────────────────────────────────────────────────────────────────


if yaml is not None:
    class Loader(yaml.SafeLoader):
        """PyYAML, but with YAML 1.2's idea of a boolean.

        PyYAML follows YAML 1.1, where `on`, `off`, `yes` and `no` are all
        booleans. A definition is written by hand to name things an API calls
        them — WLED's own state key is `on` — so 1.1 turns the most useful
        path in a widget into `True`. Here only true and false are booleans,
        which is also what `json:` and `every:` want.
        """

    for _first, _resolvers in list(Loader.yaml_implicit_resolvers.items()):
        Loader.yaml_implicit_resolvers[_first] = [
            (tag, pattern) for tag, pattern in _resolvers
            if tag != "tag:yaml.org,2002:bool"]
    Loader.add_implicit_resolver("tag:yaml.org,2002:bool",
                                 re.compile(r"^(?:true|True|TRUE|false|False|FALSE)$"),
                                 list("tTfF"))


def read_yaml(path: Path):
    if yaml is None:
        raise Invalid(str(path), "PyYAML is not installed (package: python-yaml)")
    return yaml.load(path.read_text(encoding="utf-8"), Loader=Loader)


def load_file(path: Path) -> tuple:
    """One file into a definition, or into the messages saying why not."""
    try:
        raw = read_yaml(path)
    except OSError as error:
        return None, [f"{path}: {error.strerror}"]
    except Exception as error:  # yaml's own errors carry the line already
        return None, [f"{path}: {error}"]
    if raw is None:
        return None, []
    try:
        return definition(raw, str(path), path.stem), []
    except Invalid as error:
        return None, [str(error)]



def load_all(root: Path = None) -> tuple:
    """Every definition in the directory: the plans, and what went wrong."""
    root = root or definitions_dir()
    plans = {}
    problems = []
    if not root.is_dir():
        return plans, problems
    for path in sorted(root.glob("*.y*ml")):
        loaded, errors = load_file(path)
        problems.extend(errors)
        if loaded is None:
            continue
        plan = loaded
        if plan["id"] in plans:
            problems.append(f"{path}: {plan['id']!r} is already defined")
            continue
        plans[plan["id"]] = plan
    return plans, problems


def catalogue(plans: dict) -> list:
    """The catalogue entries of every definition, by widget name."""
    return sorted((plan["catalogue"] for plan in plans.values()),
                  key=lambda entry: entry["widget"])


# ── SOURCES ─────────────────────────────────────────────────────────────────


def command_argv(command: list) -> list:
    """A command with its first word resolved, so `stats.py` means the one
    beside this file rather than whatever is on the path."""
    if not command:
        return command
    first = command[0]
    if "/" in first:
        return list(command)
    beside = scripts_dir() / first
    if beside.is_file() or first.endswith(".py"):
        if beside.is_file():
            return [str(beside), *command[1:]]
    return list(command)


def run_command(command: list, timeout: float):
    try:
        return subprocess.run(command_argv(command), capture_output=True, text=True,
                              timeout=timeout, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        raise Invalid("command", f"{command[0]} did not answer within {timeout:g}s")
    except OSError as error:
        raise Invalid("command", f"{command[0]}: {error.strerror}")


def parse_answer(body: str, source: dict, where: str):
    kind = source["parse"]
    text_body = body.strip()
    if kind == "text":
        return body.rstrip("\n")
    if kind == "number":
        try:
            return float(text_body.split()[0])
        except (ValueError, IndexError):
            raise Invalid(where, f"{text_body[:40]!r} is not a number")
    if kind == "bool":
        return text_body.lower() in ("1", "true", "yes", "on")
    if kind == "lines":
        return [line for line in body.splitlines() if line.strip() != ""]
    if kind == "csv":
        import csv as csv_module
        return [row for row in csv_module.reader(body.splitlines()) if row]
    if kind == "regex":
        found = re.search(source["pattern"], body)
        if not found:
            raise Invalid(where, f"{source['pattern']!r} is not in the answer")
        return found.group(1) if found.groups() else found.group(0)
    try:
        return json.loads(text_body)
    except ValueError:
        raise Invalid(where, f"the answer is not JSON ({text_body[:40]!r}…)")


def fetch(source: dict, where: str) -> str:
    """Whatever a source answers, as text."""
    if "command" in source:
        result = run_command(source["command"], source["timeout"])
        if result.returncode != 0:
            reason = (result.stderr or result.stdout).strip().splitlines()
            raise Invalid(where, f"{source['command'][0]} exited {result.returncode}"
                                 + (f": {reason[0]}" if reason else ""))
        return result.stdout
    if "file" in source:
        try:
            return Path(source["file"]).read_text(encoding="utf-8", errors="replace")
        except OSError as error:
            raise Invalid(where, f"{source['file']}: {error.strerror}")
    request = urllib.request.Request(
        substitute(source["url"]),
        method=source.get("method", "GET"),
        headers={key: str(value) for key, value in substitute(source.get("headers", {})).items()},
        data=(substitute(source["body"]).encode("utf-8") if source.get("body") else None))
    try:
        with urllib.request.urlopen(request, timeout=source["timeout"]) as answer:
            return answer.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        raise Invalid(where, f"{error.code} {error.reason}")
    except (urllib.error.URLError, OSError) as error:
        raise Invalid(where, str(getattr(error, "reason", error)))


def readings(source: dict, body: str, where: str) -> dict:
    """The value names a source answers, out of its answer."""
    parsed = parse_answer(body, source, where)
    out = {}
    for name, spec in source["readings"].items():
        value = parsed if spec["path"] is None else drill(parsed, spec["path"])
        if value is None:
            raise Invalid(where, f"{spec['path']!r} is not in the answer")
        if isinstance(value, str):
            try:
                value = float(value)
            except ValueError:
                pass
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            value = value * spec["scale"] + spec["offset"]
            if float(value).is_integer():
                value = int(value)
        out[name] = value
    return out


def poll(plan: dict, name: str) -> dict:
    """One source of one widget, right now."""
    source = plan["sources"][name]
    where = f"{plan['path']}: source {name}"
    return readings(source, fetch(source, where), where)


# ── ACTIONS ─────────────────────────────────────────────────────────────────


def perform(plan: dict, name: str, values=None) -> dict:
    """Do what an action says, and answer with what happened.

    Run by `widgetd.py` when the shell asks, or by `widgets.py action` on its
    own, which is what a widget's button does: the shell never makes a request
    itself, so a token stays out of the QML process.
    """
    if name not in plan["actions"]:
        return {"ok": False, "error": f"no action {name!r}",
                "actions": sorted(plan["actions"])}
    spec = plan["actions"][name]
    where = f"{plan['path']}: action {name}"
    values = values or {}

    def filled(value):
        """Substitutions, then `{name}` from the widget's own readings."""
        def swap(found):
            found_value = drill(values, found.group(1))
            if found_value is None:
                raise Invalid(where, f"{{{found.group(1)}}} is not a reading")
            return str(found_value)
        return PLACEHOLDER.sub(swap, substitute(value))

    try:
        if "url" in spec:
            body = spec.get("body") or spec.get("json")
            if isinstance(body, (dict, list)):
                body = json.dumps(body)
            request = urllib.request.Request(
                filled(spec["url"]), method=spec.get("method", "POST"),
                headers={key: filled(str(value))
                         for key, value in (spec.get("headers") or {}).items()},
                data=filled(body).encode("utf-8") if body else None)
            if body and not (spec.get("headers") or {}).get("Content-Type"):
                request.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(request, timeout=spec["timeout"]) as answer:
                    detail = answer.read().decode("utf-8", errors="replace").strip()
                    return {"ok": True, "action": name, "status": answer.status,
                            "detail": detail[:400]}
            except urllib.error.HTTPError as error:
                return {"ok": False, "action": name, "status": error.code,
                        "error": f"{error.code} {error.reason}"}
            except (urllib.error.URLError, OSError) as error:
                return {"ok": False, "action": name,
                        "error": str(getattr(error, "reason", error))}
        result = run_command([filled(part) for part in spec["command"]], spec["timeout"])
        if result.returncode != 0:
            return {"ok": False, "action": name, "status": result.returncode,
                    "error": (result.stderr or result.stdout).strip()[:400]
                             or f"exited {result.returncode}"}
        return {"ok": True, "action": name, "status": 0,
                "detail": (result.stdout or "").strip()[:400]}
    except Invalid as error:
        return {"ok": False, "action": name, "error": error.message}


# ── VERBS ───────────────────────────────────────────────────────────────────


def verb_list(argv):
    root = Path(argv[0]) if argv else definitions_dir()
    plans, problems = load_all(root)
    print(json.dumps({"widgets": catalogue(plans), "problems": problems}))
    return 1 if problems else 0


def verb_validate(argv):
    paths = [item for item in argv if not item.startswith("--")]
    root = Path(paths[0]) if paths else definitions_dir()
    plans, problems = load_all(root)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    if problems:
        return 1
    # A definition that parses is not necessarily one that answers: each
    # source is asked once, so a typo in a URL is caught here too.
    if "--poll" in argv:
        for plan in plans.values():
            for name in plan["sources"]:
                try:
                    values = poll(plan, name)
                    print(f"  {plan['id']} · {name}: "
                          + ", ".join(f"{key}={value!r}" for key, value in values.items()))
                except Invalid as error:
                    print(f"  {str(error)}", file=sys.stderr)
                    return 1
    print(f"  {len(plans)} definition{'s' if len(plans) != 1 else ''} ok")
    return 0


def verb_model(argv):
    if not argv:
        print("Usage: widgets.py model <id> [family|island]", file=sys.stderr)
        return 1
    plans, problems = load_all()
    for problem in problems:
        print(problem, file=sys.stderr)
    plan = plans.get(argv[0].removeprefix("custom:"))
    if plan is None:
        print(f"no widget {argv[0]!r}", file=sys.stderr)
        return 1
    entry = plan["catalogue"]
    if len(argv) > 1 and argv[1] == "island":
        print(json.dumps(entry["island"], indent=2))
        return 0
    family = argv[1] if len(argv) > 1 else entry["families"][0]
    if family not in entry["views"]:
        print(f"{plan['id']!r} has no {family} view; it has {entry['families']}",
              file=sys.stderr)
        return 1
    print(json.dumps(entry["views"][family], indent=2))
    return 0


def verb_action(argv):
    if len(argv) < 2:
        print("Usage: widgets.py action <id> <name> [values as a JSON object]",
              file=sys.stderr)
        return 1
    plans, _ = load_all()
    plan = plans.get(argv[0].removeprefix("custom:"))
    if plan is None:
        print(json.dumps({"ok": False, "error": f"no widget {argv[0]!r}"}))
        return 1
    values = {}
    if len(argv) > 2:
        try:
            values = json.loads(argv[2])
        except ValueError:
            print(json.dumps({"ok": False, "error": "values are not JSON"}))
            return 1
    result = perform(plan, argv[1], values)
    print(json.dumps(result))
    return 0 if result.get("ok") else 1


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    argv = sys.argv[2:]
    verbs = {"list": verb_list, "validate": verb_validate,
             "model": verb_model, "action": verb_action}
    if action not in verbs:
        print("Usage: widgets.py list | validate [dir] [--poll] | "
              "model <id> [family|island] | action <id> <name> [json]", file=sys.stderr)
        return 1
    try:
        return verbs[action](argv)
    except Invalid as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
