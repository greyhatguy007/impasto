#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   K D E   C O N N E C T                                                   │
# │   the phone: charge, what it is playing, and the rest                     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""What a paired phone is doing, and what to tell it to do.

KDE Connect's daemon owns the pairing and already publishes every device on
the session bus: its charge, the player it is playing, its network, and a
set of commands it will accept. This reads those objects and nothing else —
the shell never talks to the daemon itself, so a machine without KDE Connect
is one quiet "not available" and never an error.

The phone's notifications need nothing here: the daemon forwards them as
ordinary desktop notifications, so the shell's own notification centre shows
them already. What the bus does expose is how many the daemon is holding,
which is what a phone widget counts.

`dbus-python` is used when it is installed, because it answers without
starting a process; `gdbus` is used when it is not. Both paths answer the
same JSON, so nothing upstream has to know which one is in use.

Commands:

    providers   the paired devices, and what this machine can do with them
    status      one device, as a report
    poll        the same report, one JSON line per change
    command     ring, ping, share, clipboard, play, volume, lock

Every command writes one JSON object to stdout; a failure is reported as
`{"available": false, "reason": ...}` rather than a traceback, so the shell
keeps its last good state.
"""

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import time
from xml.etree import ElementTree

SERVICE = "org.kde.kdeconnect"
DAEMON = "/modules/kdeconnect"
DEVICES = f"{DAEMON}/devices"
TIMEOUT = 12

# How long between reads. Quick while the phone is charging or playing,
# since those are the two numbers a widget is watching, and lazy otherwise.
POLL_BUSY = 5
POLL_IDLE = 20

# A title longer than this is a notification, not a track.
TRACK_LIMIT = 300


def fail(reason, note="", connected=False):
    if note:
        print(f"kdeconnect: {reason}: {note}", file=sys.stderr)
    print(json.dumps({"available": False, "connected": connected,
                      "reason": reason}))
    sys.exit(0)


# ── GVariant ────────────────────────────────────────────────────────────────
#
# gdbus prints its answers as GVariant literals, so the handful of shapes the
# daemon uses are read back out of the text. dbus-python hands over its own
# types instead and `plain()` flattens those to the same JSON.

def plain(value):
    """dbus-python's types as the JSON the shell reads.

    They are subclasses of the plain ones, so a value that would serialise
    as a number or a string anyway is still converted here: `dbus.Boolean`
    is an int, and a settings comparison against `true` deserves a real
    boolean rather than 1.
    """
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, str):
        return str(value)
    if isinstance(value, int):
        return int(value)
    if isinstance(value, float):
        return float(value)
    if isinstance(value, dict):
        return {str(key): plain(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [plain(item) for item in value]
    try:
        return {str(key): plain(item) for key, item in value.items()}
    except AttributeError:
        return str(value)


def unquote(text):
    body = text[1:-1]
    return (body.replace("\\'", "'").replace("\\n", "\n")
            .replace("\\t", "\t").replace("\\\\", "\\"))


def parse_gvariant(text):
    """One gdbus answer as Python: a value, or a list of them."""
    if not text:
        return None
    text = text.strip()
    if text[0] in ("'", '"'):
        return unquote(text)
    if text[0] not in "([{":
        return text
    # A variant is printed in angle brackets, and one with an explicit type
    # in `@as []`. The brackets go first, or the type is left stranded.
    text = re.sub(r"[:,\[\{]\s*<", ": ", text)
    text = re.sub(r">\s*(?=[,)\]}])", "", text)
    text = re.sub(r"([([,:]\s*)@[a-z]+\s*", r"\1", text)
    text = re.sub(r"\btrue\b", "True", text)
    text = re.sub(r"\bfalse\b", "False", text)
    text = re.sub(r"\bint64\s+", "", text)
    try:
        value = ast.literal_eval(text)
    except (ValueError, SyntaxError, TypeError):
        return text
    if isinstance(value, tuple):
        return list(value) if len(value) > 1 else (value[0] if value else None)
    return value


class Raw(str):
    """A GVariant already written out, handed to gdbus as it stands.

    A property write is the one place gdbus insists on a variant of its own,
    and the `<…>` wrapper is its syntax rather than a value.
    """


def gvariant(value):
    """A GVariant literal for the gdbus path; strings are quoted."""
    if isinstance(value, Raw):
        return str(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return f"int64 {value}"
    if isinstance(value, (list, tuple)):
        if all(isinstance(item, str) for item in value):
            return "[" + ", ".join(f"'{item}'" for item in value) + "]"
        return "[" + ", ".join(str(item) for item in value) + "]"
    escaped = str(value).replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


# ── TRANSPORT ───────────────────────────────────────────────────────────────

class Bus:
    """The session bus, however this machine can reach it."""

    def __init__(self):
        self.dbus = None
        self.bus = None
        try:
            import dbus
            from dbus.mainloop.glib import DBusGMainLoop
            DBusGMainLoop(set_as_default=True)
            self.dbus = dbus
            self.bus = dbus.SessionBus()
        except Exception:
            # No bindings, or no bus: gdbus is the fallback.
            self.dbus = None

    @property
    def native(self):
        return self.dbus is not None

    def gdbus_ok(self, path, method, *arguments):
        """`gdbus call`: what came back, and whether it was called.

        The two are separate because most of what the shell asks for is a
        write or a request that answers nothing, and a method with no return
        value has not failed by having none.
        """
        command = ["gdbus", "call", "--session", "--dest", SERVICE,
                   "--object-path", path, "--method", method]
        if arguments:
            command.extend(gvariant(item) for item in arguments)
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    timeout=TIMEOUT)
        except (OSError, subprocess.SubprocessError):
            return False, None
        if result.returncode != 0:
            return False, None
        return True, parse_gvariant(result.stdout.strip())

    def gdbus(self, path, method, *arguments):
        """`gdbus call`'s answer, or None if it was not called."""
        return self.gdbus_ok(path, method, *arguments)[1]

    def device_ids(self):
        """The id of every device the daemon still holds, asleep or not.

        The daemon's object tree is the list, not the bus's names: a phone
        that has dropped off the network is still paired, and the daemon keeps
        its object for it, while its bus name is long gone. The ids are the
        node names under `devices`, and a plugin's node is not one because
        plugins live a level deeper.
        """
        if self.native:
            try:
                proxy = self.dbus.Interface(self.object(DEVICES),
                                            "org.freedesktop.DBus.Introspectable")
                tree = proxy.Introspect()
            except Exception:
                return []
        else:
            command = ["gdbus", "introspect", "--session", "--dest", SERVICE,
                       "--object-path", DEVICES]
            try:
                result = subprocess.run(command, capture_output=True, text=True,
                                        timeout=TIMEOUT)
            except (OSError, subprocess.SubprocessError):
                return []
            if result.returncode != 0:
                return []
            tree = result.stdout

        try:
            root = ElementTree.fromstring(tree)
        except ElementTree.ParseError:
            return []
        return [str(node.get("name", "")) for node in root
                if node.tag == "node" and node.get("name")]

    def interface(self, identifier, plugin):
        return (f"org.kde.kdeconnect.device" if not plugin
                else f"org.kde.kdeconnect.device.{plugin}")

    def path(self, identifier, plugin=""):
        return f"{DEVICES}/{identifier}" + (f"/{plugin}" if plugin else "")

    def object(self, path):
        """A proxy for one object, without introspecting it first: the
        daemon exports plugins as they are loaded, and introspecting a
        plugin the phone has not offered yet only earns an error on stderr.
        """
        return self.bus.get_object(SERVICE, self.dbus.ObjectPath(path),
                                   introspect=False)

    def props(self, identifier, plugin="", wanted=None):
        """A plugin's properties, or the device's own, as a plain dict.

        `GetAll` is one call for the whole object rather than one per value,
        which is what keeps polling cheap on the gdbus path.
        """
        path = self.path(identifier, plugin)
        name = self.interface(identifier, plugin)
        if self.native:
            try:
                proxy = self.dbus.Interface(self.object(path),
                                            "org.freedesktop.DBus.Properties")
                out = plain(proxy.GetAll(name))
            except Exception:
                return {}
        else:
            out = self.gdbus(path, "org.freedesktop.DBus.Properties.GetAll", name)
            if not isinstance(out, dict):
                return {}
        if wanted is None:
            return out
        return {key: out.get(key) for key in wanted if key in out}

    def invoke(self, identifier, plugin, method, *arguments):
        """Call a method: what came back, and whether it was called at all.

        The two are separate because most of what the shell asks for is a
        write or a request that answers nothing, and a method with no return
        value has not failed by having none.
        """
        path = self.path(identifier, plugin)
        interface = self.interface(identifier, plugin)
        if self.native:
            try:
                # dbus-python wants the interface, and the method off it;
                # gdbus wants both spelled out in one name.
                proxy = self.dbus.Interface(self.object(path), interface)
                return True, plain(getattr(proxy, method)(*arguments))
            except Exception:
                return False, None
        return self.gdbus_ok(path, f"{interface}.{method}", *arguments)

    def value(self, identifier, plugin, method, *arguments):
        """A method's answer, or None if it could not be called."""
        return self.invoke(identifier, plugin, method, *arguments)[1]

    def call(self, identifier, plugin, method, *arguments):
        """Ask the phone to do something; a refusal is not an error here."""
        return self.invoke(identifier, plugin, method, *arguments)[0]

    def set(self, identifier, plugin, key, value):
        """Write a property — the phone's volume, its chosen player."""
        path = self.path(identifier, plugin)
        name = f"{self.interface(identifier, plugin)}"
        if self.native:
            try:
                proxy = self.dbus.Interface(self.object(path),
                                            "org.freedesktop.DBus.Properties")
                # A property write is a variant of its own, so the value
                # needs saying so rather than being sent bare.
                if isinstance(value, bool):
                    variant = self.dbus.Boolean(value, variant_level=1)
                elif isinstance(value, int):
                    variant = self.dbus.Int64(value, variant_level=1)
                elif isinstance(value, float):
                    variant = self.dbus.Double(value, variant_level=1)
                else:
                    variant = self.dbus.String(str(value), variant_level=1)
                proxy.Set(name, key, variant)
                return True
            except Exception:
                return False
        return self.gdbus_ok(path, "org.freedesktop.DBus.Properties.Set", name, key,
                             Raw(f"<{gvariant(value)}>"))[0]

    def names(self):
        """The paired device ids, or None when there is no daemon."""
        if self.native:
            try:
                proxy = self.dbus.Interface(self.object(DAEMON),
                                            f"{SERVICE}.daemon")
                return [str(item) for item in proxy.devices(True, True)]
            except Exception:
                return None
        listed = self.gdbus(DAEMON, f"{SERVICE}.daemon.devices", True, True)
        if isinstance(listed, list):
            return [str(item) for item in listed]
        # An older daemon takes the reachability flag alone.
        listed = self.gdbus(DAEMON, f"{SERVICE}.daemon.devices", True)
        if isinstance(listed, list):
            return [str(item) for item in listed]
        return None


# ── THE REPORT ──────────────────────────────────────────────────────────────

def choose(devices, wanted=""):
    """The device the settings named, else the one that answers."""
    if wanted:
        for entry in devices.values():
            if entry["id"] == wanted or entry["name"].lower() == wanted.lower():
                return entry
        return None
    reachables = [entry for entry in devices.values() if entry["reachable"]]
    return (reachables or list(devices.values()))[0]


def paired(bus):
    """Every paired device, as `{id: {id, name, reachable, type, plugins}}`."""
    out = {}
    for identifier in bus.device_ids():
        own = bus.props(identifier, "", ["name", "type", "isPaired",
                                         "isReachable", "iconName",
                                         "statusIconName",
                                         "reachableAddresses"])
        # The daemon counts `isPaired` as an int, not a flag.
        if not own or not own.get("isPaired"):
            continue
        # The plugins a device loaded are a method, not a property, and they
        # are what says whether the shell may ring, ping or share here. A
        # phone that is asleep has none loaded, and asks again next time.
        loaded = bus.value(identifier, "", "loadedPlugins")
        if not isinstance(loaded, list):
            loaded = []
        address = own.get("reachableAddresses")
        out[identifier] = {
            "id": identifier,
            "name": str(own.get("name") or "Phone"),
            "type": str(own.get("type") or "phone"),
            "reachable": bool(own.get("isReachable", False)),
            "address": str(address[0]) if isinstance(address, list) and address else "",
            "plugins": [str(item) for item in loaded],
        }
    return out


def media_of(bus, identifier):
    """The phone's player, as one flat set of values.

    The daemon keeps the phone's players in a list that it only fills after
    being asked once, so a phone that has never been asked is asked here.
    """
    media = bus.props(identifier, "mprisremote",
                      ["title", "artist", "album", "length", "position",
                       "isPlaying", "volume", "canSeek", "playerList",
                       "localAlbumArtUrl", "player"])
    players = [str(item) for item in (media.get("playerList") or [])]
    if not players:
        bus.call(identifier, "mprisremote", "requestPlayerList")
        time.sleep(0.3)
        media = bus.props(identifier, "mprisremote",
                          ["title", "artist", "album", "length", "position",
                           "isPlaying", "volume", "canSeek", "playerList",
                           "localAlbumArtUrl", "player"])
        players = [str(item) for item in (media.get("playerList") or [])]

    title = str(media.get("title") or "")
    if not title and not players:
        return None
    return {
        "title": title,
        "artist": str(media.get("artist") or ""),
        "album": str(media.get("album") or ""),
        "art": str(media.get("localAlbumArtUrl") or ""),
        "player": str(media.get("player") or ""),
        "players": players,
        "length": int(media.get("length", 0) or 0),
        "position": int(media.get("position", 0) or 0),
        "volume": int(media.get("volume", 0) or 0),
        "playing": bool(media.get("isPlaying", False)),
        "canSeek": bool(media.get("canSeek", False)),
    }


def snapshot(bus, device):
    """One device, everything the shell draws."""
    state = {
        "available": True,
        "connected": device["reachable"],
        "id": device["id"],
        "name": device["name"],
        "type": device["type"],
        "reachable": device["reachable"],
        "address": device.get("address", ""),
        "plugins": device.get("plugins", []),
    }

    battery = bus.props(device["id"], "battery",
                        ["charge", "isCharging", "hasBattery"])
    state["battery"] = int(battery.get("charge", -1)) if battery else -1
    state["charging"] = bool(battery.get("isCharging", False)) if battery else False
    state["hasBattery"] = bool(battery.get("hasBattery", False)) if battery else False

    state["media"] = media_of(bus, device["id"])

    # How many notifications the daemon is holding for the phone. Their
    # bodies are already on screen as the shell's own.
    state["notifications"] = 0
    listed = bus.call(device["id"], "notifications", "activeNotifications")
    if listed:
        counted = bus.props(device["id"], "notifications", ["activeNotifications"])
        raw = counted.get("activeNotifications")
        state["notifications"] = len(raw) if isinstance(raw, list) else 0

    network = bus.props(device["id"], "connectivity_report",
                        ["cellularNetworkName", "cellularNetworkType",
                         "signalStrength"])
    if network:
        state["network"] = {
            "name": str(network.get("cellularNetworkName") or ""),
            "type": str(network.get("cellularNetworkType") or ""),
            "strength": int(network.get("signalStrength", 0) or 0),
        }
    else:
        state["network"] = None

    state["can"] = can(state["plugins"])
    return state


# What a pairing will actually accept, from the plugins the phone advertises.
# A desktop that shows a bell a phone will ignore is worse than no bell, so
# the shell draws the buttons from this rather than from what KDE Connect can
# do in general.
def can(plugins):
    offered = set(plugins)
    return {
        "ring": "kdeconnect_findmyphone" in offered,
        "ping": "kdeconnect_ping" in offered,
        "clipboard": "kdeconnect_clipboard" in offered,
        "media": "kdeconnect_mprisremote" in offered,
        "lock": "kdeconnect_runcommand" in offered,
        "share": shutil.which("kdeconnect-cli") is not None,
        # Forwarding is the daemon's own doing once paired; there is nothing
        # to press, so this is only what the shell has to say about it.
        "notifications": "kdeconnect_notifications" in offered,
    }


def report(bus, wanted=""):
    devices = paired(bus)
    if devices is None:
        fail("daemon", "no KDE Connect daemon on the session bus", connected=True)
    if not devices:
        fail("pairing", "no paired device", connected=True)
    device = choose(devices, wanted)
    if device is None:
        fail("input", f"no device called {wanted}", connected=True)
    state = snapshot(bus, device)
    state["devices"] = list(devices.values())
    return state


# ── COMMANDS ────────────────────────────────────────────────────────────────

def capabilities(plugins):
    """What the daemon's own plugin list says this machine can do."""
    return {
        "ring": "kdeconnect_findmyphone" in plugins,
        "ping": "kdeconnect_ping" in plugins,
        "clipboard": "kdeconnect_clipboard" in plugins,
        "media": "kdeconnect_mprisremote" in plugins,
        # Sharing is the other way round: the desktop is what receives, and
        # a share plugin is loaded here rather than on the phone, so this one
        # is the daemon's answer and the phone's plugin list cannot withdraw
        # it.
        "share": True,
        "lock": "kdeconnect_runcommand" in plugins,
        "notifications": "kdeconnect_notifications" in plugins,
    }


def providers(bus):
    devices = paired(bus)
    if devices is None:
        fail("daemon", "no KDE Connect daemon on the session bus", connected=True)
    listed = list(devices.values())
    answer = {"available": True, "connected": True, "devices": listed}
    if listed:
        answer.update(capabilities(listed[0].get("plugins", [])))
    print(json.dumps(answer))
    return 0


def send(bus, action, value="", wanted=""):
    """One action for the phone; what it can do is its own to refuse."""
    devices = paired(bus)
    if not devices:
        return {"available": False, "connected": False, "reason": "pairing"}
    device = choose(devices, wanted)
    identifier = device["id"]
    node = os.uname().nodename

    if action == "ring":
        done = bus.call(identifier, "findmyphone", "ring")
    elif action == "ping":
        done = bus.call(identifier, "ping", "sendPing", value or f"hello from {node}")
    elif action in ("play", "pause", "playpause", "next", "previous", "stop"):
        done = bus.call(identifier, "mprisremote", "sendAction", action)
    elif action == "volume":
        try:
            level = max(0, min(100, int(value)))
        except (TypeError, ValueError):
            level = 0
        done = bus.set(identifier, "mprisremote", "volume", level)
    elif action == "player":
        done = bus.set(identifier, "mprisremote", "player", value)
    elif action == "clipboard":
        done = bus.call(identifier, "clipboard", "sendClipboard")
    elif action == "push":
        done = push_clipboard(bus, identifier)
    elif action == "share":
        done = subprocess.run(["kdeconnect-cli", "--share", value],
                              capture_output=True).returncode == 0
    elif action == "text":
        done = subprocess.run(["kdeconnect-cli", "--share-text", value],
                              capture_output=True).returncode == 0
    elif action in ("lock", "unlock"):
        done = bus.call(identifier, "runcommand", "runCommand", action)
    else:
        return {"available": False, "connected": False, "reason": "input"}

    return {"available": True, "connected": done, "action": action,
            "reason": "" if done else "refused"}


# ── ENTRY ───────────────────────────────────────────────────────────────────

def copy_out(bus, identifier, previous):
    """The phone's clipboard, put on the desk's when it has changed.

    Returns the text left in the phone's clipboard, so the next pass knows
    it has already handed it over. `wl-copy` is the same door `wl-paste`
    watches, so the shell's own history sees the copy like any other.
    """
    text = bus.value(identifier, "clipboard", "content")
    if not isinstance(text, str) or text.strip() == "" or text == previous:
        return previous
    try:
        subprocess.run(["wl-copy", "--", text], capture_output=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return previous
    return text


def push_clipboard(bus, identifier):
    """The desk's clipboard, written to the phone."""
    try:
        read = subprocess.run(["wl-paste", "--no-newline"],
                              capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    if read.returncode != 0 or read.stdout.strip() == "":
        return False
    return bus.set(identifier, "clipboard", "content", read.stdout)


def poll(bus, wanted, clipboard=False):
    """The report, one line per change, until the shell stops reading.

    The phone is asked on a short timer while it is charging or playing and
    a long one otherwise; a line is written only when something moved, so an
    idle phone is a quiet process. With `clipboard` the phone's clipboard
    follows it onto the desk as it changes.
    """
    previous = None
    handed = None
    while True:
        answer = report(bus, wanted)
        if clipboard and answer.get("available") is True:
            try:
                handed = copy_out(bus, answer["id"], handed)
            except Exception:
                pass
        line = json.dumps(answer, sort_keys=True)
        if line != previous:
            print(line, flush=True)
            previous = line
        busy = answer.get("charging") or (answer.get("media") or {}).get("playing")
        time.sleep(POLL_BUSY if busy else POLL_IDLE)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "status"
    arguments = sys.argv[2:]
    bus = Bus()

    if command == "providers":
        providers(bus)
        return
    if command == "command":
        action = arguments[0] if arguments else ""
        print(json.dumps(send(bus, action, arguments[1] if len(arguments) > 1 else "")))
        return
    if command == "send":
        # The device comes first for a `send`, so the action and its value
        # stay last and read the way they are written.
        wanted, action = arguments[0], arguments[1] if len(arguments) > 1 else ""
        print(json.dumps(send(bus, action, arguments[2] if len(arguments) > 2 else "",
                              wanted)))
        return
    if command == "poll":
        poll(bus, arguments[0] if arguments else "",
             "--clipboard" in arguments)
        return
    if command == "status":
        print(json.dumps(report(bus, arguments[0] if arguments else "")))
        return
    fail("input", f"unknown command: {command}")


if __name__ == "__main__":
    main()
