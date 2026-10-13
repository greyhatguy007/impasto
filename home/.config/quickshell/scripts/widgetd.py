#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   W I D G E T D                                                          │
# │   one resident host · every widget's sources, as JSON lines              │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Run the sources of every widget and print what they answer.

Resident, because a widget's readings are wanted continuously and because the
alternative — a process per widget, or a poll in the shell — spends a process
each to do the same thing. One loop owns every schedule in the directory:

    {"kind": "catalog", "widgets": [ … ], "problems": []}
    {"kind": "data", "widget": "cpu", "values": {"load": 12.4}, "history": {"load": [ … ]}}
    {"kind": "error", "widget": "cpu", "source": "stats", "error": "…"}

The catalog goes out at the start and whenever a definition changes, so
editing a file is enough to add, change or remove a widget: the directory is
watched by its own timestamps, once every couple of seconds, which is both
cheaper and simpler than a watcher process. A source that fails keeps its last
readings and is asked again on a doubling interval, so a machine that is
offline is not asked sixty times a minute.

History is what a chart draws: the last `keep` readings of each name the
definition listed (or that a chart uses), so a sparkline needs no bookkeeping
in QML. It is sent whole each time, which is a kilobyte of floats rather than
a diff — fine at these rates, and the one thing to change if a definition ever
wants a chart of something sampled very fast.
"""

import json
import sys
import time
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import widgets  # noqa: E402  — beside this file, so it is found without a package

# How often the directory is looked at for a definition that changed, and how
# long a failed source waits before it is asked again.
WATCH_EVERY = 2.0
BACKOFF_FIRST = 2.0
BACKOFF_MOST = 60.0


def emit(**line) -> None:
    """One JSON line, at once: the shell reads this as it arrives."""
    print(json.dumps(line), flush=True)


class Source:
    """One scheduled source: when it is next due, and how it last went."""

    def __init__(self, widget_id: str, name: str, spec: dict):
        self.widget = widget_id
        self.name = name
        self.spec = spec
        self.due = 0.0
        self.streak = 0

    @property
    def every(self) -> float:
        return self.spec["every"]

    def pending(self, now: float) -> bool:
        return now >= self.due

    def schedule(self, now: float) -> None:
        """Asked again after its own interval, or after a longer wait when the
        last answers failed."""
        wait = self.every
        if self.streak:
            wait = min(self.every * (2 ** self.streak), BACKOFF_MOST)
        self.due = now + wait


class Host:
    """Every definition's sources, and the readings they have answered."""

    def __init__(self, root=None):
        self.root = root
        self.plans = {}
        self.sources = []
        self.values = {}
        self.history = {}
        self.dirty = set()
        self.failed = 0
        self.load()

    # ── DEFINITIONS ─────────────────────────────────────────────────────────

    def signature(self):
        """Cheap enough to ask often: the directory's and every file's mtime."""
        root = self.root or widgets.definitions_dir()
        if not root.is_dir():
            return ()
        out = [root.stat().st_mtime]
        for path in sorted(root.glob("*.y*ml")):
            try:
                out.append((path.name, path.stat().st_mtime, path.stat().st_size))
            except OSError:
                continue
        return tuple(out)

    def load(self) -> None:
        plans, problems = widgets.load_all(self.root)
        self.plans = plans
        self.sources = []
        self.values = {name: {} for name in plans}
        self.history = {name: {} for name in plans}
        for name, plan in plans.items():
            for source_name, spec in plan["sources"].items():
                self.sources.append(Source(name, source_name, spec))
            for value_name, keep in plan["history"].items():
                self.history[name][value_name] = deque(maxlen=keep)
        emit(kind="catalog", widgets=widgets.catalogue(plans), problems=problems)

    # ── POLLING ─────────────────────────────────────────────────────────────

    def poll(self, source: Source, now: float) -> None:
        try:
            answered = widgets.poll(self.plans[source.widget], source.name)
        except widgets.Invalid as error:
            source.streak += 1
            self.failed += 1
            emit(kind="error", widget=source.widget, source=source.name,
                 error=error.message, attempts=source.streak)
        except Exception as error:      # a source is never worth the whole host
            source.streak += 1
            self.failed += 1
            emit(kind="error", widget=source.widget, source=source.name,
                 error=f"{type(error).__name__}: {error}", attempts=source.streak)
        else:
            source.streak = 0
            self.values[source.widget].update(answered)
            for value_name, value in answered.items():
                if value_name in self.history[source.widget]:
                    self.history[source.widget][value_name].append(value)
            self.dirty.add(source.widget)
        source.schedule(now)

    def flush(self, widget_id: str) -> None:
        emit(kind="data", widget=widget_id, values=self.values[widget_id],
             history={name: list(samples)
                      for name, samples in self.history[widget_id].items()})

    def step(self, now: float) -> None:
        for source in self.sources:
            if source.pending(now):
                self.poll(source, now)
        for widget_id in sorted(self.dirty):
            self.flush(widget_id)
        self.dirty.clear()

    # ── THE LOOP ────────────────────────────────────────────────────────────

    def once(self) -> int:
        """Ask everything once and print, then stop. What a shell-less machine
        runs to see whether a definition answers at all."""
        self.step(time.monotonic())
        return 1 if self.failed else 0

    def run(self) -> int:
        seen = self.signature()
        while True:
            self.step(time.monotonic())
            time.sleep(0.2)
            found = self.signature()
            if found != seen:
                seen = found
                self.load()
                seen = self.signature()


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "run"
    root = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    if action == "run":
        try:
            return Host(root).run()
        except KeyboardInterrupt:
            return 0
    if action == "once":
        return Host(root).once()
    print("Usage: widgetd.py run [dir] | once [dir]", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
