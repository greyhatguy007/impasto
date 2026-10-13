#!/usr/bin/env python3
"""Widget DSL — arrange the desktop from a small YAML-like file.

A line starts a widget; indented lines below it set its fields.

    clock:
    battery:
      col: 3
      row: 0
      family: 2x2
      style: bare

  deck:
    notes:
      edge: left
      along: 0.35
      notes: welcome, shopping, assumptions

Decks are declared as `edge on: <edge>` lines; the first indented block
after that is the deck. `notes` is the list of keys on it (any number; if
more than one they're placed in order along the edge).

The file is $HOME/.config/quickshell/widgets.dsl by default. If it exists,
the shell reads it at startup to seed the desktop widgets; if it doesn't,
the desktop shows the default flat row and the file is written the first
time someone places a widget in Setting → Desktop.

The DSL keeps its shape: a widget line without a `key:` field uses its id as
the key. A deckline records a `deck:` key with the edge name and `notes:`
list. Extra keys placed on a widget line that don't match DesktopService
fields are recorded under their own `key:` entries and ignored from the
outside — they're preserved for the file, not consumed.

The file is kept in the same shape on write: the intent in the file is what
wins, the desktop only rearranges when someone drags a widget in Setting →
Desktop; after that drag the file is rewritten to match. The file itself
holds the ordinary order and arrangement of every placed widget, or its own
own; drag places in normal desktop layout order, and keys are kept
indentent.
"""
import re
import json
import os
import sys
from pathlib import Path
from collections import OrderedDict

# Fields the desktop widget rows define, as listed by DesktopService
WIDGET_FIELDS = {"key", "id", "screen", "col", "row", "family", "theme",
                  "style", "opacity", "note", "picture", "waveform", "loop"}

# Edge-only fields
DECK_FIELDS = WIDGET_FIELDS | {"edge", "notes", "takesNew", "along"}


def parse_value(text: str) -> str | int | float | bool | None:
    """Best-effort value: quoted string, then number, then bool, else the rest."""
    t = text.strip()
    if t == "":
        return None
    quote = (t[0] in ("'", '"'))
    if quote:
        # Strip the quote and any trailing comment
        inner = t[1:]
        end = inner.find(t[0])
        val = inner[:end] if end >= 0 else inner
        # Value may itself be quoted
        return val.strip('"').strip("'") if quote else t
    low = t.lower()
    if low in ("true", "yes"):
        return True
    if low in ("false", "no", "none"):
        return False
    try:
        return int(t)
    except ValueError:
        pass
    try:
        return float(t)
    except ValueError:
        pass
    # If the rest starts with `=` or `:` we treat it as unquoted name too.
    return t


class WidgetLine(OrderedDict):
    """One line of a widget, as a dict from field name to value."""

    def __init__(self, widget_id: str = ""):
        super().__init__()
        self._widget_id = widget_id

    @property
    def id(self) -> str:
        return self.get("id") or self._widget_id

    @id.setter
    def id(self, value: str) -> None:
        self["id"] = value
        if not self._widget_id:
            self["widget_id"] = value

    def set(self, key: str, value) -> None:
        if key in DECK_FIELDS:
            super().__setitem__(key, value)
        elif key in {"widget_id", "id"}:
            pass
        else:
            super().__setitem__(key, value)


class DeckLine(OrderedDict):
    """One deck line; stores its edge and its widget ids."""

    def __init__(self, edge: str = ""):
        super().__init__()
        self._edge = edge
        self._widgets: list[str] = []

    @property
    def edge(self) -> str:
        return self.get("edge") or self._edge

    def add_widget(self, widget: str) -> None:
        if widget not in self._widgets:
            self._widgets.append(widget)
        # store nothing else here — the list is the truth; a notes: line
        # appears once when writing


class DSL:
    """Read and write the widget DSL file.

    Widgets are plain lines; decks are marked with `deck:` in the file.
    """

    def __init__(self, path: Path):
        self.path = path
        self.widgets: dict[str, WidgetLine] = OrderedDict()
        self.decks: dict[str, DeckLine] = OrderedDict()

    def read(self) -> bool:
        """Return True if we read a real file; empty otherwise."""
        try:
            raw = self.path.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"Could not read {self.path}: {exc}", file=sys.stderr)
            return False
        if not raw:
            return True
        return self._parse_text(raw)

    def _parse_text(self, text: str) -> bool:
        lines = text.splitlines()
        indent = 0
        section = None
        deck_under = None
        widget_under = None

        for i, line in enumerate(lines):
            stripped = line.rstrip()
            if stripped.startswith("#") or not stripped:
                continue

            # Compute indent relative to the section's first widget.
            base = max(0, (len(line) - len(line.lstrip())))
            # Widgets s: count indentation of the nearest non-blank line
            # that's not itself a continuation.
            if base == 0 and ":" in stripped and "=" not in stripped:
                # Probably a widget or a deck line — an unquoted key:value
                # with the value either after the colon or on the next
                # indented lines.
                m = re.match(r"^\s*(\w[\w-]*)\s*:\s*(.*)$", stripped)
                if m:
                    name, rest = m.group(1), m.group(2).strip()
                    if name in {"widget", "widgetlist", "widgets"}:
                        section = "widgets"
                        deck_under = None
                        widget_under = None
                        continue
                    if name in {"deck", "edge"}:
                        section = "decks"
                        deck_under = name
                        widget_under = None
                        if rest:
                            # edge name after colon
                            pass
                        continue

                    # Widget id
                    section = "widgets"
                    widget_under = name
                    deck_under = None
                    wl = WidgetLine(name)
                    if rest:
                        # value on the same line as the widget
                        if rest.startswith(": ") or rest.startswith(":"):
                            # only the tag was followed by `: ` — ignore
                            pass
                        else:
                            wl.set("id", name)
                            wl.set("value", rest)
                    self.widgets[name] = wl
                    continue

            # Continuation of a widget or deck
            if widget_under and section == "widgets":
                wl = self.widgets[widget_under]
                # key: value possibly indented
                if (kv := re.match(r"^\s*(\w[\w-]*)\s*:\s*(.*)$", stripped)):
                    wl.set(kv.group(1), parse_value(kv.group(2)))
                elif ":" in stripped:
                    # key without a value? treat it as a key-only field
                    key = stripped.strip().split(":")[0]
                    wl.set(key, None)
                continue

            if deck_under and section == "decks":
                dl = self.decks.setdefault(deck_under,
                                            DeckLine(deck_under))
                if (kv := re.match(r"^\s*(\w[\w-]*)\s*:\s*(.*)$", stripped)):
                    val = parse_value(kv.group(2))
                    if kv.group(1) == "edge":
                        dl._edge = val or dl._edge
                        dl["edge"] = val or dl._edge
                    elif kv.group(1) in {"notes", "widgets"}:
                        if isinstance(val, str):
                            dl.add_widget(val)
                        elif isinstance(val, (list, tuple)):
                            for w in val:
                                dl.add_widget(str(w))
                        else:
                            dl.add_widget(str(val))
                    else:
                        dl[kv.group(1)] = val
                elif ":" in stripped:
                    key = stripped.strip().split(":")[0]
                    dl[key] = None
                continue

        return True

    def write(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        lines: list[str] = []
        for widget_id, wl in self.widgets.items():
            lines.append(f"{widget_id}:")
            for k, v in wl.items():
                if k in {"id", "widget_id"}:
                    continue
                if v is None:
                    lines.append(f"  {k}:")
                else:
                    lines.append(f"  {k}: {v}")
            lines.append("")
        for deck_id, dl in self.decks.items():
            lines.append(f"deck {dl.edge}:")
            for w in dl._widgets:
                lines.append(f"  notes: {w}")
            lines.append("")
        self.path.write_text("\n".join(lines), encoding="utf-8")

    def to_rows(self) -> list[dict]:
        """Return desktopWidgets-shaped list from current state."""
        rows: list[dict] = []
        for wl in self.widgets.values():
            row: dict[str, str] = {"key": wl.id, "id": wl.id}
            for k, v in wl.items():
                if k in {"id", "widget_id"}:
                    continue
                if v is None:
                    row[k] = ""
                else:
                    row[k] = v
            rows.append(row)
        for dl in self.decks.values():
            row: dict[str, str] = {"edge": dl.edge, "id": "notes"}
            ws = dl._widgets
            if ws:
                row["notes"] = ",".join(ws)
            rows.append(row)
        return rows

    def from_rows(self, rows: list[dict]) -> None:
        """Populate this DSL from a desktopWidgets list (placing first)."""
        self.widgets.clear()
        self.decks.clear()
        for row in rows:
            if "edge" in row:
                # deck
                dl = self.decks.setdefault(
                    row["edge"], DeckLine(row["edge"]))
                if "notes" in row and isinstance(row["notes"], str):
                    for w in row["notes"].split(","):
                        w = w.strip()
                        if w:
                            dl.add_widget(w)
            else:
                wl = WidgetLine(row.get("id", ""))
                for k, v in row.items():
                    if k in {"id", "key"}:
                        if k == "id":
                            wl.id = v
                        continue
                    wl.set(k, v)
                self.widgets[wl.id] = wl
