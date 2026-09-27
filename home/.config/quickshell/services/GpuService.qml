// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G P U   S E R V I C E                                                  │
// │   which card renders the session · chosen here, read at login            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which graphics card the session renders on (Settings → Displays).
//
// The choice is a machine setting. `gpu.py` resolves it into `gpu.tsv`, and
// `hypr/modules/env.lua` reads that when the session starts, so a change takes
// effect on the next login: Aquamarine opens the DRM cards once, and neither
// a reload nor a shell restart can reopen them.
//
// The mode the running session was opened with comes back as `IMPASTO_GPU_MODE`
// (`env.lua` sets it), so the settings can say that a restart is owed.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/gpu.py")

    // "igpu", "hybrid" or "nvidia"; set in Settings → Displays.
    readonly property string mode: SettingsService.gpuMode

    // What `gpu.py detect` found. Empty until the probe answers.
    property var found: ({})

    // A discrete card is present with its driver loaded.
    readonly property bool available: root.found.available === true

    // The card the desktop is drawn on when the discrete card is not rendering.
    readonly property var integrated: root.found.integrated ?? null

    // The mode this session was opened with, from `env.lua`. A machine whose
    // session predates the setting (or has no state file) is on the iGPU.
    readonly property string sessionMode:
        Quickshell.env("IMPASTO_GPU_MODE") || "igpu"

    // The choice has not reached the running session yet.
    readonly property bool pending: root.mode !== root.sessionMode

    // ── PROBE ───────────────────────────────────────────────────────────────

    function probe(): void {
        root.prober.running = true
    }

    readonly property Process prober: Process {
        command: [root.script, "detect"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.found = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the graphics cards:", error)
                }
                root.apply()
            }
        }
    }

    // ── STATE FILE ──────────────────────────────────────────────────────────
    //
    // Written for whichever mode is chosen, including the default, so
    // `env.lua` always has a file to read. The devices behind the mode are
    // resolved by the script from `/sys/class/drm`, never from a card number.

    function apply(): void {
        root.writer.command = [root.script, "write", root.mode]
        root.writer.running = true
    }

    readonly property Process writer: Process {
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("The graphics mode could not be written:", exitCode)
        }
    }

    // A change while the probe has not answered yet is written by the probe's
    // own `apply()` once it has, so only fire here when it already has.
    onModeChanged: {
        if (Object.keys(root.found).length > 0)
            root.apply()
    }

    Component.onCompleted: root.probe()
}
