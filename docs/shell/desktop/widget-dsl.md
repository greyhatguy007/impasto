# Widget DSL

The desktop widgets can be arranged from a file: one widget per line, fields
set under it. It's an arranged shorthand — the file both describes the layout
and gives the shell the pieces it needs to place them. Editing the file
changes the desktop after the next read (startup, or the reload button in
Settings → Desktop), so you can keep a layout in the file and the desktop
matches it.

## A short file

A file at `~/.config/quickshell/widgets.dsl`:

```yaml
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
```

- A top-level line is a widget placed at its default spot.
- Indented lines under it set fields: `col`, `row`, `family`, `style`,
  `opacity`, `note`, `picture`, and the theme-related ones the desktop knows.
- A block under `deck` declares a deck on the given edge; `notes:` gives the
  keys in order along that edge, one per line.
- `edge` is one of `left`, `right`, `bottom`; `notes` takes a comma-separated
  list of note keys.

## Field reference

| Key | Value | Placement |
|-----|-------|-----------|
| `id` | widget name | optional — the line's name is the id |
| `col`, `row` | integer cell | default: `0` |
| `family` | `2x2`, `4x2`, `4x4`, `8x2` | default: the widget's first family |
| `theme` | `modern`, `analogue` | default: desktop theme |
| `style` | `capsule`, `accent`, `outline`, `bare` | default: desktop style |
| `opacity` | percent 0–100 | default: desktop opacity |
| `note` | note key (for a notes widget) | optional |
| `picture` | path or `file://…` (for a photo widget) | optional |

Deck fields:

| Key | Value | Default |
|-----|-------|---------|
| `edge` | `left`, `right`, `bottom` | required |
| `notes` | comma-separated keys | none |
| `takesNew` | `true`/`false` | false |

A widget line may also carry a `key: value` pair on the same line; the parser
treats `something: rest` as a key if `rest` is present, else as a key-only
flag. That keeps the file readable and lets you write `clock:` as just a
widget with no options.

## Notes

- The file is read at startup and whenever the settings gadget reloads the
  desktop from it. A widget dragged in Settings → Desktop rewrites the file
  to match, so the two stay in sync.
- Notes that aren't on any deck or grid are kept in the file and will be
  placed next time someone opens the desktop.
- Empty files are fine — they get the default flat row.
- Resizing a widget's family in the setting keeps the cell, moving it to a
  different column/row in the file keeps its position.
- The file is kept in the same shape the shell reads it; you can edit it
  directly and the desktop follows, but it's easier to use drag-and-drop and
  let the file track.

## Converting an existing arrangement to the file

The widget DSL is a companion to the desktop arrangement: if you have widgets
placed in the desktop, they're stored the same way the file is, and dragging
a widget onto a deck from the Settings → Desktop panel rewrites the file with
that placement. The first time you open a desktop with the file present, the
shell reads it and places the widgets; after that, when you drag in the
desktop, the file tracks the result.

## Troubleshooting

- **Widget not placed**: the id is wrong or the widget doesn't exist. Check
  the spelling in the line and the available modules in Settings → Desktop.
- **Wrong position**: the `col`/`row` may be out of range for the family or
  the screen the widget is on.
- **Deck not showing**: the edge is wrong or the list of notes is empty; the
  deck is hidden until it has notes.
- **Whole layout disappears**: the DSL file has a parse error. The shell keeps
  the last good layout and ignores the file when it can't read it, so rename
  it and re-create slowly.

The file uses `\` as its line-continuation — a trailing `\` continues the
value on the next line, which lets you write long lists.
