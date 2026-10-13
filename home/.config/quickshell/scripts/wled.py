#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   W L E D                                                                │
# │   screen-aware lighting · the screen's colours over DDP                   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Stream the screen's colours to WLED lights over DDP (UDP 4048).

`wled.py discover` answers with every WLED on the network that names itself
(`wled.py status <host>` says how many LEDs one has). `wled.py stream <host>`
stays resident: it downsamples a screen photo once per tick and sends one DDP
packet per 480 LEDs, the way WLED's own realtime UI does.

Like `compositor.py`, nothing here writes a Lua file or a setting: the shell
keeps the host and the options, starts and stops the stream by owning the
process, and this script only ever answers or streams.

DDP is the protocol WLED's docs recommend for realtime data: one packet holds
up to 480 RGB triples so a long strip is sent in a few datagrams, and the
controller leaves `heap_fragmentation` alone. WLED switches itself back a
moment after the stream stops.

Resident mode reports one JSON line per tick, so the service's SplitParser can
refresh its figures without a poll of its own:

    {"fps": 23, "packets": 46, "leds": 1188, "changed": 0.62}
"""

import json
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

# DDP: header 10 bytes, then the payload. Source is 1, and a full answer is
# one packet of at most 480 triples, which is what WLED reads per datagram.
DDP_PORT = 4048
DDP_HEADER = struct.pack(">BBBBHBB", 0x41, 0x01, 0x00, 0x01, 0, 0, 0)
TRIPLES_PER_PACKET = 480

# The screen is sampled to this width; the strip's order matters more than the
# row they came from.
SAMPLE_WIDTH = 32

# The photo is retaken no faster than this even when asked, so a slow grim
# never queues behind itself.
MIN_TICK = 1 / 40


def run(command, **kwargs):
    kwargs.setdefault("stdin", subprocess.DEVNULL)
    try:
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=120, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def report(**fields):
    print(json.dumps(fields), flush=True)


def magick():
    for name in ("magick", "convert"):
        if shutil.which(name):
            return name
    return ""


# ── DISCOVERY ────────────────────────────────────────────────────────────────
#
# WLED answers its own JSON API on port 80. Nothing is assumed about the
# network beyond that: `discover` finds nothing by magic, it asks mDNS and
# then the addresses avahi already knows.


def probes():
    """The tools discovery can use; both are optional."""
    return {
        "avahi": bool(shutil.which("avahi-browse")),
        "socket": socket is not None,
    }


def discover():
    tools = probes()
    found = []
    if tools["avahi"]:
        result = run(["avahi-browse", "-prt", "_wled._tcp"])
        if result is not None:
            for line in result.stdout.splitlines():
                parts = line.split(";")
                # type, protocol, name, service, domain, host, address, port
                if len(parts) < 8 or parts[0] != "=" or parts[3] != "_wled._tcp":
                    continue
                host = parts[6].strip()
                name = parts[2].strip()
                if host and host not in [entry["host"] for entry in found]:
                    found.append(describe(host, name))
    report(tools=tools, lights=found)


def describe(host, name, leds=0):
    """One controller, as far as it is known before its own status is asked."""
    return {"host": host, "name": name, "leds": leds}


# ── STATUS ──────────────────────────────────────────────────────────────────


def status(host):
    """One controller, as far as its JSON API tells it."""
    try:
        with socket.create_connection((host, 80), timeout=3) as wire:
            wire.sendall(b"GET /json/info HTTP/1.1\r\nHost: wled\r\n"
                         b"Connection: close\r\n\r\n")
            chunks = []
            while True:
                part = wire.recv(65536)
                if not part:
                    break
                chunks.append(part)
        body = b"".join(chunks).split(b"\r\n\r\n", 1)
        info = json.loads(body[1]) if len(body) > 1 else {}
    except (OSError, ValueError):
        info = {}
    light = info.get("info") or {}
    leds_block = light.get("leds")
    report(
        host=host,
        name=light.get("name") or "",
        version=light.get("ver") or "",
        leds=leds_block.get("count", 0) if isinstance(leds_block, dict) else 0,
        reachable=info != {},
    )


# ── STREAMING ───────────────────────────────────────────────────────────────


def screen_capture(output=""):
    """One screenshot path, or None. Same as `capture.py grab`."""
    if not shutil.which("grim"):
        return None
    handle, name = tempfile.mkstemp(prefix="impasto-wled-", suffix=".png",
                                    dir=str(runtime_dir()))
    os.close(handle)
    command = ["grim"]
    if output:
        command += ["-o", output]
    result = run(command + [name])
    if result is None or result.returncode != 0:
        os.unlink(name)
        return None
    return name


def runtime_dir():
    return os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()


def sample(path, count):
    """`count` RGB triples read left to right down the photo."""
    tool = magick()
    if not tool:
        return None
    text = run([tool, str(path), "-resize", f"{SAMPLE_WIDTH}x1!", "-depth", "8",
                "-flip", "txt:-"])
    if text is None or text.returncode != 0:
        return None
    rows = []
    for line in text.stdout.splitlines():
        if "#" not in line:
            continue
        hex_col = line.split("#", 1)[1][:6]
        if len(hex_col) != 6:
            continue
        try:
            rows.append(int(hex_col[0:2], 16))
            rows.append(int(hex_col[2:4], 16))
            rows.append(int(hex_col[4:6], 16))
        except ValueError:
            continue
    triples = len(rows) // 3
    if triples == 0:
        return None
    # Spread `count` reads over what we have, so every LED on the strip gets
    # its own colour even when the sample is shorter than the strip.
    stride = max(1, (triples - 1) / max(1, count - 1)) if count > 1 else 1
    out = []
    for index in range(count):
        at = min(triples - 1, int(index * stride))
        out.extend(rows[at * 3:at * 3 + 3])
    return bytes(out[:count * 3])


def stream(host, output, count, fps, minimum_change):
    """Stay resident: sample the screen, send it over DDP, report the tick."""
    wire = None
    frames = packets = 0
    last = bytes()
    seen = 0.0
    try:
        wire = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    except OSError as error:
        report(error=f"cannot open UDP: {error}")
        return
    while True:
        started = time.monotonic()
        picture = screen_capture(output)
        if picture is None:
            report(error="grim is not here")
            time.sleep(1)
            continue
        try:
            payload = sample(picture, count)
        finally:
            os.unlink(picture)
        if payload is None:
            report(error="ImageMagick is not here")
            time.sleep(1)
            continue
        # One packet per 480 triples, like WLED's realtime UI.
        sent = 0
        for start in range(0, len(payload), TRIPLES_PER_PACKET * 3):
            chunk = payload[start:start + TRIPLES_PER_PACKET * 3]
            wire.sendto(DDP_HEADER + chunk, (host, DDP_PORT))
            sent += 1
        packets += sent
        changed = 0
        if last:
            moved = sum(1 for at in range(0, len(payload), 3)
                        if payload[at:at + 3] != last[at:at + 3])
            changed = moved / (len(payload) / 3)
        last = payload
        frames += 1
        rate = frames / max(0.001, time.monotonic() - seen)
        report(fps=round(rate, 1), packets=packets, leds=count,
               changed=round(changed, 3))
        seen = time.monotonic()
        rest = MIN_TICK - (time.monotonic() - started)
        if rest > 0:
            time.sleep(rest)


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "discover"

    if action in ("discover", "probe"):
        discover()
        return
    if action == "status" and len(arguments) > 1:
        status(arguments[1])
        return
    if action == "stream" and len(arguments) > 2:
        host = arguments[1]
        count = int(arguments[2])
        output = ""
        fps = 24
        minimum_change = 0.02
        rest = arguments[3:]
        while rest:
            flag = rest.pop(0)
            if flag == "--output" and rest:
                output = rest.pop(0)
            elif flag == "--fps" and rest:
                fps = max(1, min(60, int(rest.pop(0))))
            elif flag == "--min-change" and rest:
                minimum_change = max(0.0, min(1.0, float(rest.pop(0))))
        stream(host, output, count, fps, minimum_change)
        return

    report(error=f"No such wled action: {action}")


if __name__ == "__main__":
    main()
