# Impasto Enhancement Plan

This document outlines three main initiatives:
1. Diagnosing and resolving the multi-monitor cursor movement issue.
2. Integrating Vikunja (self-hosted todo/kanban) into the impasto ecosystem, including Google Calendar integration via Vikunja.
3. Diagnosing and resolving the simpmusic freeze issue.

Each section includes non-invasive diagnostic steps (for the cursor and simpmusic issues) and a detailed planning phase (for Vikunja integration) without requiring immediate code changes.

---

## 1. Multi-Monitor Cursor Issue Diagnosis

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

#### Step 4: Review Input and Monitor Modules
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

---

## 2. Vikunja Integration Plan

### Objective
Seamlessly integrate Vikunja (self-hosted todo/kanban) into impasto, leveraging the existing quickshell widgets, island UI, and keybind system for contextual, glanceable task management.

## 3. SimPMusic Freeze Issue Diagnosis

### Objective
Diagnose and resolve why simpmusic (a desktop music application) freezes or becomes unresponsive in the impasto environment.

### Non-Invasive Diagnostic Steps

#### Step 1: Test simpmusic in Isolation
- Launch simpmusic from a clean terminal session (outside of any special environment)
- Observe if the freeze occurs immediately or after specific actions (playing music, changing tracks, etc.)
- If it works fine outside Hyprland/impasto, the issue is environment-specific
- If it fails even in isolation, the issue may be with the application itself or its dependencies

#### Step 2: Check Application Logs
- Run simpmusic with verbose/debug output if available:
  ```bash
  simpmusic --verbose
  simpmusic --debug
  simpmusic --log-level=debug
  ```
- Check for any error messages in the terminal output when it freezes
- Look for application-specific log files (often in `~/.local/share/simpmusic/` or `~/.config/simpmusic/`)

#### Step 3: Verify Dependencies
- Check if simpmusic has all required dependencies installed:
  ```bash
  # Common dependencies for music players
  pacman -Qs gstreamer pulseaudio alsa libmpv vlc qt5-base qt6-base
  ```
- Specifically check for audio backend dependencies (PulseAudio, PipeWire, ALSA, etc.)
- Check for GUI toolkit dependencies (Qt, GTK, etc.)

#### Step 4: Test with Different Audio Backends
- Since audio applications often freeze due to audio server issues:
  - Ensure your audio server (PipeWire/PulseAudio) is running: `wpctl status` or `pulseaudio --check`
  - Try restarting the audio server: `systemctl --user restart pipewire pipewire-pulse` (or equivalent for PulseAudio)
  - Test if other audio applications work correctly to isolate if it's a system-wide audio issue

#### Step 5: Check for GPU/Graphics Issues
- Some applications freeze due to GPU acceleration problems:
  - Try launching with software rendering if available: `simpmusic --disable-gpu` or similar flag
  - Check if other OpenGL/Vulkan applications work correctly
  - Verify your graphics drivers are functioning properly

#### Step 6: Examine Hyprland-Specific Conflicts
- Test if the issue occurs with specific Hyprland features:
  - Disable animations temporarily: `hyprctl keyword animations:enabled 0`
  - Test if it works on a different workspace or monitor configuration
  - Check if any window rules in `windowrules.lua` might be affecting it
  - Test if it works when floating vs tiled

#### Step 7: Check for Input/Grab Issues
- Since simpmusic might be capturing input unexpectedly:
  - Check if keyboard/mouse still works in other applications when simpmusic is "frozen"
  - Try to switch workspaces or open a terminal to see if the system is responsive
  - If only simpmusic is unresponsive but system works, it's likely an application-level freeze
  - If entire system becomes unresponsive, it could be a deeper issue (driver, audio deadlock, etc.)

#### Step 8: Resource Usage Check
- When simpmusic appears frozen, check system resources from another terminal:
  ```bash
  top          # Check CPU usage
  htop         # More detailed process view
  free -h      # Check memory usage
  ```
- Look for simpmusic consuming excessive CPU (infinite loop) or being stuck in uninterruptible sleep (D state)

#### Step 9: Test with Alternative Configurations
- Launch simpmusic with a clean configuration:
  ```bash
  mv ~/.config/simpmusic ~/.config/simpmusic.backup  # Backup config
  simpmusic  # Test with defaults
  ```
- If it works with clean config, gradually restore settings to identify problematic option

#### Step 10: Check for Known Issues
- Search simpmusic's issue tracker (GitHub/GitLab) for similar freeze reports
- Check if there are known compatibility issues with specific library versions
- Look for recent updates that might have introduced regressions

### Outcome
After completing these steps, you should have a clearer understanding of whether the freeze is:
- Application-specific (bug in simpmusic itself)
- Environment-specific (conflict with Hyprland/quickshell/audio setup)
- Resource-related (memory leak, CPU spin)
- Dependency-related (missing or incompatible library)

Fixes would then involve:
- Reporting bugs to simpmusic upstream if it's an application issue
- Adjusting audio/PipeWire configuration if it's a sound server conflict
- Modifying Hyprland window rules or settings if it's a compositor interaction
- Updating/reinstalling dependencies if it's a library issue
- Finding workaround flags or settings in simpmusic to disable problematic features

### Integration Overview
Vikunja will appear as:
- A **quickshell widget** (compact view on the bar, expandable in the island).
- A **contextual island glance** (triggered by tags in notes or manual keybind).
- An **enhanced mode** in existing notes (`Super + S`) and task board (`Super + K`) tools.
- Background sync via a lightweight daemon (similar to `awww-daemon`).

### Key Design Principles
- **Minimal Intrusion**: Vikunja data appears only when relevant (glance/widget) or via explicit user action.
- **Leverage Existing Patterns**: Reuse quickshell theming, motion, and island anatomy.
- **Two-Way Sync**: Allow quick task completion/capture from the widget/island.
- **Context Awareness**: Surface Vikunja tasks related to active work (e.g., note tags, current project).
- **Offline Resilience**: Cache last-known state; indicate staleness when offline.

### Implementation Plan (Phased)

#### Phase 0: Preparation & Validation
- [ ] **API Exploration**: 
  - Test Vikunja API endpoints (tasks, projects, labels) with a personal token.
  - Note response structure (e.g., `/api/v1/tasks` returns array of objects with `title`, `done`, `project_id`, `due_date`, `labels`).
- [ ] **Token Storage Strategy**:
  - Decide on secure storage location (e.g., `$XDG_STATE_HOME/impasto/vikunja.conf` with `chmod 600`).
  - Plan to load token in `modules/env.lua` or a new `modules/vikunja.lua`.
- [ ] **Quickshell Widget Feasibility**:
  - Create a mock QML widget in quickshell’s widget directory showing hardcoded task data.
  - Verify it uses existing `Theme.qml` for colors, fonts, and motion.

#### Phase 1: Core Widget & Sync Daemon (Foundation)
- [ ] **Vikunja Module** (`home/.config/hypr/modules/vikunja.lua`):
  - Load URL and token from secure config.
  - Expose helper functions: `fetchTasks(filter)`, `markTaskDone(id)`, `createTask(data)`.
  - Handle API errors gracefully (return cached data on failure).
- [ ] **Sync Daemon**:
  - Write a lightweight Lua/Python script (or reuse quickshell’s polling) to:
    - Fetch tasks from Vikunja every 2-5 minutes.
    - Store filtered results (e.g., today’s tasks, starred projects) in `$XDG_STATE_HOME/impasto/vikunja_cache.json`.
    - Emit a signal (via file or dbus) quickshell can listen to for updates.
  - Integrate into `autostart.lua` (commented out initially for testing):
    ```lua
    hl.exec_cmd("vikunja-sync-daemon")  -- · background sync
    ```
- [ ] **Quickshell Widget**:
  - Develop a QML widget that:
    - Reads cached data from `vikunja_cache.json`.
    - Displays 2-3 top-priority tasks for today (with project/label icons).
    - On hover/tooltip: shows full task list.
    - On click: opens expanded view in the island (see Phase 2).
    - Uses quickshell’s standard animation presets for expand/collapse.
  - Style using the current quickshell theme (no new colors; map Vikunja labels to existing palette accents).

#### Phase 2: Island Glance & Contextual Triggers
- [ ] **Island Glance Mechanism**:
  - Extend the island’s shape-shifting logic to recognize a `"vikunja"` mode.
  - When activated:
    - Island expands to show a compact Kanban (To Do/In Progress/Done) or list view of tasks.
    - Uses existing island rounding (22px) and shadow (if enabled).
    - Taps on tasks toggle completion (optimistic UI update; syncs in background).
    - Pull-to-refresh gesture to manually sync.
  - Activation methods:
    - Manual keybind: `Super + Shift + V` → `hl.dsp.global("quickshell:vikunja")`.
    - Contextual: Detect Vikunja-related tags in active note/editor → island suggests glance (subtle pulse).
- [ ] **Contextual Triggers**:
  - In notes (`Super + S`):
    - Add a "Share to Vikunja" button in the notes UI.
    - On click: open a quickshell prompt to select project/labels → create task from note content.
  - In task board (`Super + K`):
    - Add a Vikunja tab alongside local notes.
    - Tab loads projects from cache; clicking a project shows its tasks.
    - Allow dragging local tasks to Vikunja column to sync (future enhancement).

#### Phase 3: Enhancements & Polish
- [ ] **Two-Way Sync for Widget Actions**:
  - Completing a task in the widget/island → optimistic update → background sync → revert on failure with notification.
- [ ] **Motion & Feedback**:
  - Use quickshell’s `Motion.qml` for widget expand/collapse and island glance animations.
  - Add subtle haptic feedback (if supported) for task completion.
- [ ] **Error States**:
  - Widget shows a subtle badge (like update nags) on sync failure.
  - Tap badge to retry or view error details (logged to `vikunja-sync-daemon` output).
- [ ] **Advanced Filtering**:
  - Allow widget to show tasks by project (via quickshell settings).
  - Add "overdue" or "high priority" views accessible via widget context menu.
- [ ] **Voice Input Integration**:
  - Leverage existing note-taking voice input: "Add Vikunja task: [speech]" → creates task via API.

### Non-Code Considerations
- **Security**: Never log tokens; ensure config file is user-readable only.
- **Performance**: Limit API payloads (use `?select=title,done,due_date,project_id,label_names` if supported).
- **Battery/Network**: Respect system settings; pause sync on metered connections or low power.
- **Fallback**: If Vikunja is unreachable, widget shows last known state with "offline" indicator.
- **Documentation**: Update impasto README with a "Vikunja Integration" section detailing setup (token creation, config file).

### Example File Structure (Post-Implementation)
```
home/
├─ .config/
│  └─ hypr/
│     ├─ modules/
│     │  ├─ autostart.lua        -- + vikunja-sync-daemon line
│     │  ├─ env.lua              -- loads Vikunja token (or new vikunja.lua)
│     │  ├─ vikunja.lua          -- API wrapper, token loader
│     │  └─ ...                  -- existing modules unchanged
│  └─ quickshell/
│     ├─ widgets/
│     │  └─ VikunjaWidget.qml    -- bar widget + island glance logic
│     └─ ...                     -- existing quickshell files
├─ .local/
│  └─ state/
│     └─ impasto/
│        ├─ vikunja.conf         -- URL and token (chmod 600)
│        └─ vikunja_cache.json   -- synced task data (JSON)
└─ ...                           -- rest of impasto
```

### Success Metrics
- [ ] Cursor moves freely between monitors (post-diagnosis fix).
- [ ] Vikunja widget shows live data without impacting system performance.
- [ ] Completing a task from the widget/island reflects in Vikunja within sync interval.
- [ ] Adding a task from notes via "Share to Vikunja" appears in the correct project.
- [ ] Island glance animates smoothly using existing motion principles.
- [ ] Offline mode displays cached data with clear staleness indicator.

---

### Next Steps
1. **Cursor Issue**: Perform the diagnostic steps outlined in Section 1. Document findings.
2. **Vikunja**: Begin with Phase 0 (validation) to confirm API feasibility and token storage method.
3. **Prototype**: Build a minimal QML widget showing static data to validate UI integration.
4. **Iterate**: Progress through phases, testing each incrementally.

This plan ensures both initiatives are tackled methodically, leveraging impasto’s existing strengths while minimizing risk through observation and incremental validation.