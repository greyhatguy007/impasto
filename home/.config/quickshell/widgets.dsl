# Example widget arrangement.
# Every line is a widget; indented lines set fields.
# Move this file to ~/.config/quickshell/widgets.dsl and restart, or
# edit it in place: the desktop follows it after a reload.

# ── Top-row widgets ──────────────────────────────────────────────────

clock:
media:
battery:
  col: 2
  row: 0

# ── Music-forward bar ────────────────────────────────────────────────

lyrics:
  col: 3
  row: 0
  family: 4x2

brightness:
  col: 0
  row: 1

# ── Glowing strip ───────────────────────────────────────────────────

wled:
  col: 1
  row: 1
  family: 4x2

# ── Edge deck of notes ─────────────────────────────────────────────

deck left:
  notes: welcome
  notes: shopping
  notes: assumptions
