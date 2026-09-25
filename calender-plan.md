# Impasto Calendar & Task Integration Plan (Option B)

## Overview
This plan implements direct integration of Vikunja tasks and Google Calendar events into impasto, bypassing Vikunja's CalDAV limitations. Impasto will fetch data from both sources independently and present a unified view.

## Architecture
```
[Google Calendar] ──(REST API)──→ [impasto] ←──(REST API)── [Vikunja Server]
                                ↑
                    [Quickshell Widget/Island]
```

## Core Components
1. **Vikunja Module** (`home/.config/hypr/modules/vikunja.lua`) - Enhanced
2. **Google Calendar Module** (`home/.config/hypr/modules/gcalendar.lua`) - New
3. **Unified Data Aggregator** (`home/.config/hypr/modules/schedule.lua`) - New
4. **Quickshell Widget** (`home/.config/quickshell/widgets/ScheduleWidget.qml`) - New/Enhanced
5. **Island Glance Logic** (in quickshell core) - Enhanced
6. **Keybinds** (`home/.config/hypr/modules/keybinds.lua`) - Enhanced

## Implementation Plan

### Phase 0: Preparation & Validation
- [ ] **Vikunja API Validation**
  - Confirm endpoints: `/api/v1/tasks`, `/api/v1/projects`, `/api/v1/labels`
  - Test auth with Bearer token
  - Note response structure for task creation/completion
- [ ] **Google Calendar API Validation**
  - Create Google Cloud project & OAuth credentials
  - Enable Google Calendar API
  - Test endpoints: `/calendars/v3/calendars/primary/events`
  - Note required scopes: `https://www.googleapis.com/auth/calendar`
  - Plan token storage (refresh token flow)
- [ ] **Token Storage Strategy**
  - Vikunja: `$XDG_STATE_HOME/impasto/vikunja.conf` (URL + token)
  - Google Calendar: `$XDG_STATE_HOME/impasto/gcalendar.conf` (client_id, client_secret, refresh_token)
  - Both files chmod 600
- [ ] **Data Structure Design**
  - Unified item format: `{id, type: "task"|"event", title, start, end, allDay, completed, description, location, labels/projects, source}`

### Phase 1: Core Modules & Data Fetching
- [ ] **Vikunja Module Enhancements**
  - Add `fetchEvents()` (if Vikunja has native events) OR reuse `fetchTasks()` with filtering
  - Add `markComplete(id)`, `createTask(data)`
  - Error handling with cached fallback
- [ ] **Google Calendar Module** (New)
  - `home/.config/hypr/modules/gcalendar.lua`:
    - Load OAuth credentials from secure config
    - Implement token refresh flow using refresh token
    - Functions: `fetchEvents(timeMin, timeMax)`, `createEvent(data)`, `markAttended(eventId)`
    - Handle API errors, rate limiting
    - Cache events locally (optional)
- [ ] **Schedule Aggregator Module** (New)
  - `home/.config/hypr/modules/schedule.lua`:
    - Import vikunja and gcalendar modules
    - `fetchToday()` → calls both, merges, sorts by start time
    - `fetchUpcoming(days)` → for widget views
    - Apply user preferences (show/hide completed, specific calendars/projects)
    - Return unified list of items
- [ ] **Autostart Integration**
  - No daemons needed - modules fetch on demand
  - Consider adding lightweight cache to reduce API calls (optional)

### Phase 2: UI Implementation
- [ ] **Quickshell Widget** (`ScheduleWidget.qml`)
  - Display: Compact view showing next 3-5 items (tasks + events)
  - Visual distinctions:
    - Events: Time blocks (if timed), all-day banners
    - Tasks: Checkbox items
    - Icons: 📅 for events, ✅/⭕ for tasks
    - Color coding: Use Vikunja labels or Google Calendar colors
  - Interactions:
    - Hover: Tooltip with full details
    - Click task: Toggle completion (optimistic UI)
    - Click event: Toggle attendance status (if supported)
    - Pull-to-refresh: Manual sync
  - Animation: Use existing `Motion.qml` presets
- [ ] **Island Glance Mechanism**
  - Extend island to recognize `"agenda"` mode
  - Display: Chronological list of today's items
    - Header: Date
    - Sections: Morning, Afternoon, Evening
    - Visual distinction between event types
    - Ongoing item highlight
  - Activation:
    - Keybind: `Super + Shift + C` → `hl.dsp.global("quickshell:agenda")`
    - Contextual: Detect schedule tags in notes → island pulse
    - Alternative: Hover over clock in bar → show glance
- [ ] **Contextual Triggers Enhancement**
  - In notes (`Super + S`):
    - Add "Schedule from note" button
    - Opens quickshell prompt: "When?" + natural language parsing
    - Creates event in Google Calendar OR task in Vikunja (user choice)
  - In task board (`Super + K`):
    - Add a "Schedule" tab alongside existing views
    - Shows unified schedule from aggregator
    - Drag tasks to time slots → creates timed event/task

### Phase 3: Polish & Features
- [ ] **Two-Way Sync**
  - Completing task in widget → update Vikunja
  - Marking event attended → update Google Calendar (if API supports)
  - Optimistic UI updates with failure rollback
- [ ] **Smart Event Creation**
  - Voice input: "Meeting with John tomorrow 3pm" → parse → create event
  - Simple regex/nlp for time extraction
- [ ] **Error States**
  - Widget shows subtle badge on API failure
  - Tap to retry or view error details (logged)
  - Distinguish Vikunja vs Google Calendar errors
- [ ] **Visibility Controls**
  - Widget settings: Show only specific Vikunja projects/labels
  - Widget settings: Show only specific Google Calendars
  - "Focus time" feature: Auto-block time for high-priority tasks (future)
- [ ] **Offline Support**
  - Cache last successful fetch in `$XDG_STATE_HOME/impasto/schedule_cache.json`
  - Show cached data with "offline" indicator when APIs unreachable
  - Queue offline actions for retry

## File Changes Required

### New Files:
1. `home/.config/hypr/modules/gcalendar.lua`
2. `home/.config/hypr/modules/schedule.lua`
3. `home/.config/quickshell/widgets/ScheduleWidget.qml`
4. `$XDG_STATE_HOME/impasto/gcalendar.conf` (template)
5. `$XDG_STATE_HOME/impasto/schedule_cache.json` (auto-generated)

### Modified Files:
1. `home/.config/hypr/modules/vikunja.lua` (enhance for events)
2. `home/.config/hypr/modules/keybinds.lua` (add schedule bindings)
3. `home/.config/hypr/modules/autostart.lua` (optional: add cache warmer)
4. `home/.config/quickshell/` (core: add agenda mode to island logic)
5. `home/.config/hypr/modules/programs.lua` (add calendar helper if needed)

## Success Metrics
- [ ] Widget shows live tasks + events from both sources
- [ ] Completing task in widget updates Vikunja within 5 seconds
- [ ] Creating event from notes appears in Google Calendar
- [ ] Island glance animates smoothly using existing motion
- [ ] Offline mode displays cached data with clear indicator
- [ ] Error states are informative and actionable
- [ ] No significant performance impact on system responsiveness

## Next Steps for Implementation
1. **Week 1**: Validate APIs and create token storage
   - Test Vikunja API with sample token
   - Set up Google Cloud project and test Calendar API
   - Design secure config file formats
2. **Week 2**: Build core modules
   - Implement gcalendar.lua with OAuth flow
   - Enhance vikunja.lua for event handling
   - Create schedule.lua aggregator
3. **Week 3**: Implement UI
   - Build ScheduleWidget.qml with basic display
   - Add island glance mechanism
   - Implement keybinds
4. **Week 4**: Polish and features
   - Add two-way sync actions
   - Implement smart event creation
   - Add error handling and offline support
   - Test with real usage

## Non-Code Considerations
- **Security**: Never log tokens; ensure config files are user-readable only (chmod 600)
- **Performance**: 
  - Limit API payloads with field selection (`?fields=summary,start,end,description`)
  - Debounce widget updates (max 1x per 5 seconds)
  - Cache aggressively; refresh only on user action or timeout
- **Battery/Network**: 
  - Respect system settings; reduce update frequency on battery power
  - Pause automatic refresh on metered connections
- **Fallback Strategy**: 
  - If one service fails, show data from the other with warning
  - Clear indication of which source is offline
- **User Experience**: 
  - Follow existing impasto theming and motion principles
  - Keep interactions discoverable but not intrusive
  - Maintain visual consistency with track widget, etc.

## Why This Approach Works
- **Correctly Handles Vikunja Limitations**: No false assumption about Vikunja being CalDAV client
- **Leverages Existing Strengths**: Uses impasto's Lua/QML architecture effectively
- **Provides Real User Choice**: Users can use Vikunja-only, Google-only, or both
- **Minimal Dependencies**: Only requires standard Lua libraries (luasocket, lua-json) and QML
- **Transparent Sync**: Users see exactly where data comes from and goes to
- **Extensible Design**: Easy to add other sources (Exchange, iCloud) later via same pattern


## Multi-Monitor Cursor Issue Diagnosis

### Objective
Identify why the cursor cannot move between monitors in a multi-monitor setup.

### Non-Invasive Diagnostic Steps

#### Step 1: Verify Monitor Geometry
- Run: `hyprctl monitors`
- Check each monitor's:
  - `resolution` (width x height)
  - `position` (top-left corner coordinates, e.g., `pos: 1920,0` for a monitor to the right of a 1920px wide primary)
  - `scale` (should be consistent across monitors; mixed scaling can cause cursor "jumping" or barriers)
  - `active workspace` (to ensure workspaces are correctly assigned per monitor)

#### Step 2: Test with Default Hyprland Configuration
- Backup current config: `mv ~/.config/hypr ~/.config/hypr.backup`
- Start Hyprland with default config (no custom modules).
- Test cursor movement between monitors.
  - **If cursor works**: Issue lies within custom config (proceed to Step 3).
  - **If cursor still fails**: Potential driver, hardware, or compositor issue (outside scope of config diagnosis).

#### Step 3: Isolate Quickshell Influence
- Comment out the quickshell autostart line in `home/.config/hypr/modules/autostart.lua`:
  ```lua
  -- hl.exec_cmd("qs -d")   -- · bar and notifications (quickshell)
  ```
- Restart Hyprland.
- Test cursor movement.
  - **If fixed**: Quickshell may be interfering with input (e.g., unintended input grab).
  - **If not fixed**: Issue likely in Hyprland monitor/input configuration.

#### Step 4: Review Input and Monitor
- Examine `home/.config/hypr/modules/monitors.lua` for:
  - Any `hl.monitor()` calls with unusual `position` or `scale` overrides.
  - Missing monitor configurations (though Hyprland often auto-detects).
- Check for existence of `home/.config/hypr/modules/input.lua` (if present, review for custom input rules, sensitivity, or acceleration settings that might affect cursor movement).

#### Step 5: Check for Conflicting Grabs or Regions
- Run: `hyprctl keyword general:mouse_enable` → should be `true`.
- Search for any `region` or `exclude` directives in config that might inadvertently restrict cursor zones (unlikely but possible via plugins or windowrules).
- Verify no active compositor-level input blockers (e.g., a screenshot tool or overlay running).

#### Step 6: Monitor Dynamic Changes (if applicable)
- If using docking/undocking or hotplugging:
  - Run `hyprctl monitor` before and after a monitor change to see if Hyprland updates configurations correctly.
  - Ensure the `MonitorService` (referenced in comments) is functioning as expected (no need to modify; just observe).

#### Step 7: Log Analysis (if issue persists)
- Start Hyprland with verbose logging: `Hyprland --verbose 2>~/hypr.log`
- Attempt to move cursor between monitors, then stop Hyprland.
- Check `~/hypr.log` for input-related errors or warnings (look for `input`, `cursor`, `monitor` keywords).

### Outcome
After completing these steps, you should have a clear hypothesis about the root cause (e.g., mismatched scales, quickshell interference, misconfigured monitor positions). Fixes would then involve:
- Adjusting `scale` or `position` in `monitors.lua`.
- Reporting quickshell interaction issues (if found).
- Ensuring monitor profiles are correctly applied via the existing `MonitorService` runtime mechanism.


## Enhancement Ideas (Apple-Inspired Features)

### 1. Universal Search Bar (Spotlight Alternative)
- **How it fits**: Extend existing `Super + Space` launcher (quickshell:launcher)
- **Implementation**:
  - Enhance launcher to search: files (via `fzf`/`ripgrep`), contacts, clipboard history, quickshell commands, Vikunja tasks, browser history
  - Use preview pane showing results (like Spotlight's rich previews)
  - Leverage quickshell's existing QML framework for UI
- **Non-code prep**: 
  - Define search providers as QML modules
  - Map keyboard shortcuts in `keybinds.lua` for specialized searches (e.g., `Super + O` for files only)

### 2. Continuity-Style Handoff (Limited but Useful)
- **How it fits**: Use existing notification/system integration
- **Implementation**:
  - "Send to device" option in notes/task widgets (via Pushbullet/KDE Connect alternative)
  - Clipboard sync with mobile (already have `Super + V` clipboard history)
  - App state persistence: when opening a note/task, suggest continuing from mobile session
- **Non-code prep**:
  - Audit existing notification daemons for extension points
  - Define handoff protocol (simple HTTP endpoint to quickshell)

### 3. Menu Bar Extras (Apple's Status Items)
- **How it fits**: Your quickshell bar already hosts widgets (track, etc.)
- **Implementation**:
  - Create lightweight QML widgets for:
    - Battery percentage with charging animation
    - Network speed monitor (upload/download arrows)
    - Audio input level meter (mic activity)
    - Active VPN indicator
  - Make them collapsible/expandable on hover (like Apple's menu bar extras)
- **Non-code prep**:
  - Study existing widget structure in quickshell
  - Define data sources (using `hyprctl`/`systemctl`/`pactl` etc.)

### 4. Focus Modes (Do Not Disturb + Context)
- **How it fits**: Extend your session/menu system (`Super + X`)
- **Implementation**:
  - Predefined profiles that toggle:
    - Notification filters (quickshell:doNotDisturb)
    - Workspace layouts (specific monitors/apps)
    - Widget visibility (hide distracting widgets)
    - Automatic status messages (for chat apps)
  - Trigger via: time/location (via geoclue), app detection, or manual keybind
- **Non-code prep**:
  - Extend `modules/env.lua` or create `modules/focus.lua`
  - Define focus states as Lua tables (apps to show/hide, notification rules)

### 5. Desktop Stage Manager Alternative
- **How it fits**: Your existing workspace/window management
- **Implementation**:
  - "Project Spaces": predefined workspace groups (e.g., "Web Dev" = browser + editor + terminal on specific monitors)
  - One-key activation (`Super + P` → choose project → auto-arranges windows)
  - Uses your existing `hl.dispatch()` window management + workspace logic
- **Non-code prep**:
  - Define project configurations as Lua tables
  - Extend keybinds module with project selector UI (via quickshell)

These enhancement ideas build upon impasto's existing architecture and can be implemented incrementally as future phases after the core calendar/task integration is complete.