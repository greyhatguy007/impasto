#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   G P U                                                                  │
# │   graphics cards · which one renders, and offloading to the discrete     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Find the DRM cards and write down which one the session should use.

Like `monitors.py`, this never writes `hypr/*.lua`: the chosen mode is a shell
setting, and the devices behind it are resolved here and written to `gpu.tsv`
in the state directory, which `hypr/modules/env.lua` reads at startup.

`detect` reads the cards straight from `/sys/class/drm`, so the outcome does
not depend on the numbering `cardN` happens to take. `write` turns a mode into
that file, and `offload` starts one command on the discrete card with the PRIME
render-offload variables set.
"""

import json
import os
import pathlib
import sys

DRM = pathlib.Path("/sys/class/drm")

# The vendor a DRM card belongs to, by PCI vendor id. Only the first is a
# candidate for rendering; the rest are the cards it renders alongside.
VENDORS = {
    "0x10de": "nvidia",
    "0x1002": "amd",
    "0x8086": "intel",
}

# The states a session can be in. `igpu` leaves Aquamarine to sort the cards
# out on its own; the other two name a render device.
MODES = ("igpu", "hybrid", "nvidia")

# For a program started on the discrete card. The first two are read by the
# GLX/EGL loader and the Vulkan layer; CUDA and the compute APIs are reached
# through the device the driver exports on its own.
OFFLOAD_ENV = {
    "__NV_PRIME_RENDER_OFFLOAD": "1",
    "__GLX_VENDOR_LIBRARY_NAME": "nvidia",
    "__VK_LAYER_NV_optimus": "NVIDIA_only",
}


# ── CARDS ───────────────────────────────────────────────────────────────────


def read_text(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def read_link_name(path):
    """The name a symlink points at, empty when it points nowhere."""
    try:
        return os.path.basename(os.path.realpath(path))
    except OSError:
        return ""


def connectors(card):
    """The output names this card is driving, `cardN-<port>` without the card."""
    found = []
    for node in sorted(DRM.glob(f"{card.name}-*")):
        if read_text(node / "status") == "connected":
            found.append(node.name[len(card.name) + 1:])
    return found


def card_info(card):
    device = card / "device"
    vendor_id = read_text(device / "vendor")
    return {
        "id": card.name,
        "card": f"/dev/dri/{card.name}",
        "vendor_id": vendor_id,
        "vendor": VENDORS.get(vendor_id, vendor_id or "unknown"),
        "pci": read_link_name(device),
        "driver": read_link_name(device / "driver"),
        "outputs": connectors(card),
    }


def detect():
    cards = []
    for card in sorted(DRM.glob("card[0-9]*")):
        # The glob also catches the connector nodes, `card1-eDP-1`.
        if "-" in card.name:
            continue
        cards.append(card_info(card))

    nvidia = next((c for c in cards if c["driver"].startswith("nvidia")), None)
    integrated = next((c for c in cards if c["vendor"] in ("amd", "intel")
                       and not c["driver"].startswith("nvidia")), None)
    return {
        "available": nvidia is not None,
        "nvidia": nvidia,
        "integrated": integrated,
        "cards": cards,
    }


# ── STATE ───────────────────────────────────────────────────────────────────

# Read by `env.lua`, which turns it into the environment Aquamarine opens the
# cards in. An edit here is overwritten by `write`.
HEADER = (
    "# Graphics: the card the session renders on. A `mode` of igpu, hybrid or\n"
    "# nvidia; `render` is the card that draws and `accel` the one beside it.\n"
    "# Written by the shell from Settings → Displays and read by\n"
    "# hypr/modules/env.lua, so an edit here is overwritten.\n"
)


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(
        os.environ.get("HOME", ""), ".local", "state")
    return pathlib.Path(base) / "quickshell"


def resolve(mode, found):
    """The mode to record, and the two devices it names.

    A mode naming a card the machine does not have falls back to `igpu`: a
    laptop left with no render device at all would not start a session.
    """
    nvidia = found["nvidia"]
    integrated = found["integrated"]

    if mode == "nvidia" and nvidia:
        return mode, nvidia["card"], integrated["card"] if integrated else ""
    if mode == "hybrid" and nvidia and integrated:
        return mode, integrated["card"], nvidia["card"]
    return "igpu", integrated["card"] if integrated else "", ""


def write_state(mode):
    if mode not in MODES:
        print(f"gpu.py: unknown mode: {mode}", file=sys.stderr)
        return None
    found = detect()
    mode, render, accel = resolve(mode, found)

    lines = [f"mode\t{mode}"]
    if render:
        lines.append(f"render\t{render}")
    if accel:
        lines.append(f"accel\t{accel}")

    path = state_dir() / "gpu.tsv"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(HEADER + "\n".join(lines) + "\n")
    return {"mode": mode, "render": render, "accel": accel, **found}


# ── OFFLOAD ─────────────────────────────────────────────────────────────────


def offload(argv):
    """Exec `argv` on the discrete card, replacing this process."""
    if not argv:
        print("usage: gpu.py offload <command> [args...]", file=sys.stderr)
        return 2
    env = dict(os.environ, **OFFLOAD_ENV)
    try:
        os.execvpe(argv[0], argv, env)
    except FileNotFoundError:
        print(f"gpu.py: not found: {argv[0]}", file=sys.stderr)
        return 127
    return 0


# ── ENTRY ───────────────────────────────────────────────────────────────────


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "detect"

    if action == "detect":
        print(json.dumps(detect()))
    elif action == "write":
        wanted = sys.argv[2] if len(sys.argv) > 2 else "igpu"
        written = write_state(wanted)
        if written is None:
            return 2
        print(json.dumps(written))
    elif action == "offload":
        rest = sys.argv[2:]
        if rest and rest[0] == "--":
            rest = rest[1:]
        return offload(rest)
    else:
        print(f"gpu.py: unknown action: {action}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
