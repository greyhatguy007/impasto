# Integrations

How impasto is pointed at the services it speaks to, and where each one shows
up. Everything lives in **Settings → Integrations**, and every credential is
kept on the machine that set it: a profile switch never carries a key to
another desk.

---

## Vikunja — the task board, with a server behind it

A self-hosted Vikunja server turns the local board (`SUPER + K`) into a two-way
synced one: the server's tasks fold into the same list the board already
draws, and changes made here are sent back.

### Setup

1. In Vikunja: **Settings → API tokens** → create a token with read and write
   on tasks and projects.
2. In impasto: **Settings → Integrations → Tasks**
   - **Server** — the base address, e.g. `https://tasks.example.com` (no
     `/api/v1` suffix; the shell adds it)
   - **API token** — paste the token (masked; the eye reveals it)
   - **Project** — which project new tasks land in. Leave empty to use the
     first project the token owns.
   - **Sync** — the master switch
3. The board footer, bottom right, shows where things stand: `synced just
   now · N tasks on the server`, or the reason it is not.

### How the sync behaves

- Reads happen every 5 minutes and on any credential change; **Sync now**
  forces one.
- A change made here is sent at once (a short debounce groups bursts). Until
  the server confirms, the task carries a small pending mark on the board.
- Deleting a task the server knows about deletes it there too. Tasks made
  here and deleted before the first send simply go.
- Turning sync off (or removing a credential) removes the server's tasks from
  the board but keeps anything typed but not yet sent, as ordinary local
  tasks.
- If the server is unreachable, the last good state stays on screen and the
  footer says why.

### Reasons the board and settings can show

| Reason | Meaning |
|---|---|
| Add a server and an API token | No credentials yet |
| The token was refused | Wrong or revoked token (401/403) |
| The server did not answer | The URL is wrong, or the server answered badly |
| No connection to the server | Network unreachable |
| No project to put a task in | Creating a task with no project to put it in |
| The change could not be sent | The server refused an edit |
| The script could not be run | The helper script could not start — see
  [troubleshooting](#troubleshooting) |

---

## Google Calendar — the days, beside the tasks

With Google Calendar connected, the calendar surfaces around the shell gain
your events: dots on the month, events listed under a day's tasks, and the
next events in the date module. **Read-only** — the shell writes nothing to
your calendar.

### Setup

One-time work in Google Cloud Console, about five minutes:

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and
   create a project (any name, e.g. `impasto`).
2. **APIs & Services → Library** → search **Google Calendar API** → **Enable**.
3. **APIs & Services → OAuth consent screen**
   - User type **External** (for a personal Google account); fill in an app
     name and your email.
   - Under **Audience / Test users**, **add your own Google account**. This is
     the step people miss — without it Google blocks the sign-in at the
     browser step.
4. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Desktop app** — this kind is required; it is what
     allows the shell's local redirect, per RFC 8252.
   - Name it, then copy the **Client ID** and **Client secret**.
5. In impasto: **Settings → Integrations → Calendar**
   - Paste the **Client id** and **Client secret**.
   - **Calendar** — `primary` is your main calendar; any other calendar id
     works too.
   - Press **Connect**. The browser opens once: pick the account, and on
     *Google hasn't verified this app* choose **Advanced → Go to (app name)
     (unsafe)** — expected, it is your own unlisted app — then **Allow**.
6. The row reads **Connected · the token is on this machine**, and Sync shows
   the events in view.

### Where the events appear

- **The date module on the bar** — a *Coming up* list of the next events when
  today has none; click through days as usual.
- **The calendar card in the control centre** — wheel through months; a day
  with an event gets a **blue dot** (the accent dot stays for tasks) and is
  clickable. The day view lists events under the tasks: time in the mono
  font, all-day events in italics, an event happening now in the accent.
- **Desktop widgets** — the wide (4×2) calendar draws the week with dots for
  tasks *and* events; **scroll** to page through weeks, click a date to see
  that day's tasks and events, and the widget returns to the current week
  when the pointer leaves.
- Events are read every 15 minutes, from a week ago to a quarter ahead, so a
  date months out still gets its dot.

### What is stored, and where

The **refresh token never enters the settings file**. The connect script
keeps it in `~/.local/state/quickshell/gcalendar.json`, user-only (mode 600),
on the machine that connected — so a profile switch never carries the key,
and the settings file stays free of secrets. The client id and secret live in
the per-machine part of the settings.

**Disconnect** revokes the token at Google and deletes the file.

### Reasons the calendar can show

| Reason | Meaning |
|---|---|
| Add the client id and secret | Half or none of the OAuth client is set |
| Connect once in the browser | Credentials are set but never connected |
| Google refused the key | The token was refused — connect again |
| Google did not answer | The request failed at Google's side |
| No connection to Google | Network unreachable |
| The script could not be run | The helper script could not start — see
  [troubleshooting](#troubleshooting) |

---

## Assistant usage — what the block and the week have cost

A usage bar on the island and a face on the desk, counted from the transcripts
the assistants already write on this machine. **Nothing is sent anywhere.**

- **Settings → Integrations → Assistant usage** — the source (*Everything*,
  or one assistant on its own), the two quotas, and any extra transcript
  directories.
- The **block** is five hours from an assistant's first message, so the
  countdown to the reset is exact; the **week** is the rolling seven days.
- Cache reads are reported but not counted: they re-send context the provider
  has already seen.
- Without a quota the ring shows how long the block has been running and
  claims no percentage, since a percentage of what?

### Where the numbers come from

| Source | Read from | Plan's own figures |
|---|---|---|
| Claude Code | `~/.claude/projects` | Asked for in the settings |
| pi | `~/.pi/agent/sessions` | Asked for in the settings |
| OmniRoute | the pi logs, filtered to that provider | — |
| Everything | the two above, added together | — |

Transcripts only ever grow, so each file is read from its last offset and the
hourly buckets are cached under `~/.local/state/quickshell/ai-usage.json`.
A machine whose logs live somewhere else says so in **Extra directories**,
one path per line.

### Reasons the usage can show

| Reason | Meaning |
|---|---|
| No transcripts found | The folder is not there — set an extra directory |
| No usage found in … | The folder is there and empty; nothing has been used |
| The script could not be run | The helper script could not start — see
  [troubleshooting](#troubleshooting) |

---

## KDE Connect — the phone on this desk

The paired phone as a second bar module, a desktop face, and — if you want it
— a player and a clipboard for the whole desk. Pairing happens in
**KDE Connect** itself; impasto only reads what the daemon already knows.

- **Settings → Integrations → Paired phone** — which device (one phone on a
  desk needs no choice: *The one that answers*), and the three optional
  behaviours: the phone's music takes over the desk's player, a copy made on
  the phone lands on the desk's clipboard, and a greeting on unlock.
- The bar module only offers what **this** pairing answers to. A phone that
  refuses to be rung is not shown a bell.
- The face draws the phone's charge as a phone, not as a second battery.

### What is stored, and where

Nothing. The device list comes from the KDE Connect daemon over the session
bus; impasto keeps no device data, and **the phone is named only where the
shell already draws the module or the face**.

### Reasons the phone can show

| Reason | Meaning |
|---|---|
| KDE Connect is not running | The daemon is not on the session bus — start
  KDE Connect, or the phone simply is not a shell feature right now |
| No paired phone | The daemon is up and knows no device — pair one there |
| That phone is not paired | A saved id the daemon no longer holds |
| *name* · out of reach | Paired, and asleep: the daemon still holds it and
  the phone is simply not answering |
| No battery report | The phone reported no battery level |
| The script could not be run | The helper script could not start — see
  [troubleshooting](#troubleshooting) |

---

---

## Activity — GitHub, LeetCode, Codeforces, GitLab

The activity wall (the `coding` module and its desktop faces) draws a rolling
year for every platform with a handle set, read from public profiles, no
token needed:

- **Settings → Widgets → Activity** — enter the handles. A wrong name is
  flagged on its own field.
- With more than one handle, the widget's toggle (or hovering the desktop
  wall) picks **All** — every platform's days added together and capped — or
  a single platform in its own colour.
- GitLab counts public events (pushes, merge requests, issues, comments);
  private contributions are invisible without a token and are not fetched.

---

## Troubleshooting

**"The script could not be run" (or a service stuck at *reaching the
server…*)** — the helper script could not be *started at all*. The shell runs
the scripts in `~/.config/quickshell/scripts/` by direct execution, so the
file must be executable. After adding or copying a script:

```bash
chmod +x ~/.config/quickshell/scripts/*.py
```

Remember that file *contents* survive a copy between machines but the
executable **mode does not always travel** — check the live copy, not the
repository.

**Credentials look right but nothing syncs** — toggle the service's **Sync**
switch off and on; that forces an immediate read. `qs log | grep -i
vikunja` (or `gcalendar`) shows what the scripts said.

**The browser never opens when connecting** — the authorize URL is printed to
the shell's log; open it by hand: `qs log | grep gcalendar`.

**Everything else** — each integration's *Sync now* row states exactly what
it is doing and why it is not, in the same words as the table above.
