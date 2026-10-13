# Custom widgets

A widget can be described in a file instead of written in QML. One file brings
a widget to the desktop and the bar: where its readings come from, how they are
drawn at each size, what its chip shows in the island, and what its buttons do
when they are pressed. The file is a definition, so a widget of your own reads
like a widget the shell ships — it is dragged, sized and placed the same way,
and it can reach a REST endpoint or run a command on this machine.

They live in `~/.config/quickshell/widgets/`, one YAML file per widget. The
shell ships three as examples: `cpu.yaml` (local, no network), `weather.yaml`
(a REST endpoint with no key) and `lights.yaml` (a REST endpoint with a token,
and buttons).

## A definition, start to finish

```yaml
id: lights
name: Lights

sources:
  state:
    url: "http://${secret:wledHost}/json/state"
    every: 3s
    parse: json
    values:
      on: on
      brightness: bri

actions:
  toggle:
    url: "http://${secret:wledHost}/json/state"
    method: POST
    json: { on: t }

history:
  brightness: 60

view:
  "4x2":
    - kind: row
      gap: 12
      grow: 1
      children:
        - { kind: icon, glyph: "󰚥", size: 22, role: accent }
        - { kind: text, text: "Lights", role: text }
        - { kind: gauge, value: brightness, max: 255, grow: 1 }
        - { kind: button, action: toggle, label: "On / off", role: accent }

island:
  width: 356
  height: 150
  symbol: "󰚥"
  figure: "{brightness}"
  detail:
    - kind: row
      gap: 10
      children:
        - { kind: button, action: toggle, label: "On / off", role: accent, grow: 1 }
```

`${secret:wledHost}` is the address Settings → Integrations already writes when
you point this desk at a controller. The file holds no token, so it is safe to
copy, share or commit.

## Sources

Each name under `sources:` is one thing to ask, on its own schedule.

| Key | Value |
|-----|-------|
| `url` | an HTTP or HTTPS endpoint |
| `method` | `GET` (default), `POST`, … |
| `headers` | a map of request headers |
| `body` | a request body, as a string |
| `command` | a command instead of a URL, as a list of arguments |
| `file` | a file to read instead of a URL |
| `every` | how often to ask: `500ms`, `3s`, `10m`, `1h`, or a bare number of seconds |
| `parse` | `json`, `text`, `number`, `bool`, `lines`, `csv`, `regex` |
| `pattern` | what to pick out, when `parse` is `regex` |
| `timeout` | seconds to wait for an answer (default 10) |
| `values` | the readings, and where each sits in the answer |

`values:` maps a reading name to a path into the parsed answer — `current.temperature_2m`,
`state.bri`, `cpu.total`. A reading can also be rescaled on the way in:

```yaml
    values:
      memory: { path: memory.used, scale: 9.3132257461547852e-10 }
      temp:   { path: temperature.celsius, offset: -273.15 }
```

A source that fails keeps its last readings and is asked again on a doubling
interval — up to a minute — so a machine that is offline is not asked sixty
times a minute. The widget shows why it has nothing rather than a row of
dashes.

`command:` names a script beside the shell's own (`scripts/`), so `stats.py`
means the one that ships with this desk; anything with a `/` in it is run as
written. It never goes through a shell, so a definition cannot turn into a
command line by accident.

## Values in text

Anywhere text is written, `{name}` is filled in from the readings and
`{name:.1f}` formats it: `.0f`, `.2f`, `d` (whole), `%` (times a hundred),
`e`. A template that names something no source answers is refused when the
definition is read, so a typo is caught before the desktop sees it.

```yaml
- { kind: text, text: "{temp:.0f}°C · feels {feels:.0f}°", role: text }
```

## The view

`view:` has one list of elements per family — `"2x2"`, `"4x2"`, `"4x4"`,
`"8x2"`. A family left out is simply not offered in Settings → Desktop.

**Leaves**

| Element | Fields |
|---------|--------|
| `text` | `text`, `role`, `size`, `bold`, `mono`, `wrap`, `align`, `valign` |
| `bar` | `value`, `min` (0), `max` (100), `role`, `thickness`, `rounded`, `label` |
| `gauge` | `value`, `min`, `max`, `role`, `thickness`, `label`, `size` |
| `chart` | `value`, `min`, `max`, `role`, `style` (`line`, `area`, `bars`), `span`, `thickness` |
| `icon` | one of `glyph`, `svg`, `image`, plus `size`, `role` |
| `button` | `action`, and a `label` or a `glyph`, plus `role`, `size`, `confirm` |
| `divider` | `role`, `thickness`, `vertical` |
| `spacer` | `grow` |

**Containers**

| Element | Fields |
|---------|--------|
| `row`, `column` | `children`, `gap`, `align`, `justify` |
| `grid` | `children`, `columns`, `gap`, `align` |

`role` names a colour rather than giving one: `text`, `muted`, `accent`,
`accentText`, `raised`, `ground`, `border`, `dim`, `good`, `warn`, `bad`. The
desktop fills in what those mean for its theme, so a widget follows the
wallpaper and the theme it is placed in.

`grow` takes what is left over: give it to the element that should stretch,
and leave it off the ones that should stay their own size. `align` places an
element across its row or column (`start`, `center`, `end`, `fill`), `justify`
places the children along it (`start`, `center`, `end`).

`chart` draws the last `span` samples of a value (60 by default) — the
readings are kept by the host, so nothing has to be remembered in the shell.
`history:` says how many samples to keep per reading, 60 by default; a reading
a chart draws is kept whether or not it is listed.

## Buttons and what they do

A button names an action, and an action is the only way a widget changes
something. The shell does not make the request itself: it asks this desk's
python, which makes it out of sight of the QML process. A token therefore
never enters the shell's own memory, and a button cannot be turned into a
request by anything that can write QML.

```yaml
actions:
  # A REST action: a URL, a method, and what to send.
  brighter:
    url: "http://${secret:wledHost}/json/state"
    method: POST
    headers: { Authorization: "Bearer ${secret:wledToken}" }
    json: { bri: 200 }

  # A reading can go into the request, from what the widget is showing.
  set:
    url: "http://${secret:wledHost}/json/state"
    method: POST
    json: { bri: "{brightness}" }

  # A command action: same block, no url.
  off:
    command: [wled.py, status, "${secret:wledHost}"]
    confirm: true
```

| Key | Value |
|-----|-------|
| `url` | what to ask |
| `method` | `POST` by default; `GET`, `PUT`, `PATCH`, `DELETE` |
| `json` | an object sent as JSON (and `Content-Type` set for you) |
| `body` | a body as a string, when it is not JSON |
| `headers` | request headers |
| `command` | a command instead of a URL, as a list of arguments |
| `timeout` | seconds to wait (default 10) |
| `confirm` | ask for a second click within four seconds before it fires |

`${secret:name}` is a key of the shell's own settings.json, where
Settings → Integrations already keeps every token; `${env:NAME}` is the
environment, for anything the shell should not keep at all. Both can appear in
a URL, a header, a body or a command. If a key is missing, the widget says so
where its readings would be — `no 'wledHost' in the shell's settings` — rather
than failing silently.

One action runs at a time. Its button dims while it is out, and the answer is
shown on the desk's own OSD: a widget cannot lie about what happened. An
action that takes `confirm` arms on the first press — its outline goes accent
and its label reads `… again?` — and fires on the second.

Buttons can appear anywhere in a view: on the desktop at any family, in the
island's `detail:`, and in a row of their own. A definition can put the same
button at several sizes, as `lights.yaml` does with its three.

## The island

`island:` gives the widget a chip on the bar and the panel it opens into.

```yaml
island:
  width: 356          # the panel's size, in logical pixels
  height: 150
  symbol: "󰚥"         # the chip's glyph
  figure: "{bri}"     # the chip's reading, filled from the sources
  detail: [ … ]       # elements, exactly as in a view
```

## Checking a definition

```bash
cd ~/.config/quickshell

./scripts/widgets.py list              # every definition the shell can see
./scripts/widgets.py validate          # parse, and check every name a template uses
./scripts/widgets.py validate --poll   # …and ask every source once
./scripts/widgets.py model lights 4x2  # the elements one family is drawn from
./scripts/widgets.py action lights toggle   # fire one action, as a button would
```

`./setup check` runs `validate` over the definitions in the repository, so a
broken one is caught in CI rather than drawn as a dash on the desktop. Pass a
directory to check a copy of them instead: `widgets.py validate /tmp/other`.

## How it runs

`scripts/widgetd.py` is a single resident process that owns every definition's
schedule and prints a JSON line whenever something is answered:

```
{"kind": "catalog", "widgets": [ … ], "problems": []}
{"kind": "data", "widget": "lights", "values": {"brightness": 128}, "history": { … }}
{"kind": "error", "widget": "lights", "source": "state", "error": "…"}
```

`WidgetService.qml` reads those lines and hands them to the widgets. The
process is restarted by the shell if it stops, so a widget does not quietly go
stale. Definitions are picked up by their own timestamps every couple of
seconds: save a file and the widget appears, changes or disappears. Nothing is
asked of the network until a source says how often it wants to be.

## Troubleshooting

- **The widget is not in Settings → Desktop**: the file did not parse. Run
  `widgets.py validate`; it names the file and the line.
- **It draws dashes**: its sources have not answered yet, or its identifier is
  wrong. `widgets.py validate --poll` asks them once and reports why.
- **A button does nothing**: the action it names is missing, or its first press
  armed a `confirm`. `widgets.py action <id> <name>` says which.
- **A button says the token is missing**: add the key to Settings →
  Integrations, or export it and use `${env:…}`.
- **The island has no chip**: `island:` needs `symbol` and a `width`/`height`.
