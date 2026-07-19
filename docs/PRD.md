# PRD — EyeBreak (working name)

**An open-source macOS menu-bar app that reduces digital eye strain through 20-20-20 break habits.**

- Status: Build-ready. This document plus `docs/USER_SPEC.md` are the only inputs the implementing agent needs.
- Source of truth for health objectives, copy constraints, and non-goals: `docs/USER_SPEC.md`. Where this PRD and USER_SPEC.md appear to conflict, USER_SPEC.md wins.
- Inspiration: LookAway (lookaway.com) was studied for feature ideas and UX patterns only. This is an independent implementation. **Do not copy LookAway's copy, branding, names, screenshots, or assets.** The working name "EyeBreak" is a placeholder; any name is fine as long as it is not confusable with "LookAway".

---

## 1. Problem statement

People who work on laptops for long stretches — developers especially — experience screen-related eye discomfort: strain, dryness, blurred focus after long near-focus sessions. Screen use suppresses blink rate and encourages continuous near focus, both associated with dry-eye symptoms and visual fatigue.

The best-supported, low-risk interventions are behavioral: regular look-away breaks (the 20-20-20 habit), deliberate blinking, and dry-eye self-care (warm compresses, lubricating drops, environment fixes). The bottleneck is adherence, not knowledge. Existing high-quality tools for macOS (e.g. LookAway) are closed-source and paid.

**EyeBreak** is a minimal, free, open-source, local-only menu-bar app that makes the 20-20-20 habit easy to keep: gentle full-screen break prompts, snooze/skip that never punish, quiet mode for calls and presentations, idle awareness so it never nags an empty chair, and comfort-habit stats.

### Target users

1. **Developers / laptop-heavy knowledge workers** — long uninterrupted focus sessions, often full-screen editors/terminals, frequent calls and screen sharing. Skeptical of nagware; will uninstall anything punitive or resource-hungry.
2. **People with existing dry-eye discomfort** — want the optional self-care reminders (blink, warm compress, drops) in addition to breaks.
3. **Open-source users** — want auditable, no-network, no-analytics software they can build themselves with `swift build`.

---

## 2. Health objective and copy rules

### Health objective (from USER_SPEC.md)

Target the most supported, low-risk interventions for screen-related eye discomfort:

- Regular look-away breaks (20-20-20).
- Reduced continuous near-focus time.
- Better blinking behavior.
- Dry-eye support (warm compresses, lubricating drops, environment fixes).

The app's benefit claim is **symptom reduction and comfort**, never prescription change or vision improvement.

- Primary outcome: improve comfort during prolonged screen work by increasing look-away breaks and reducing uninterrupted near-focus time.
- Secondary outcomes: support blinking, reduce dryness triggers, remind users about proven self-care steps (warm compresses, lubricating drops) when relevant.

### Conservative health-copy rules (MANDATORY for all in-app text, README, App name, release notes)

**Allowed phrasing (use these or equivalents at the same level of caution):**

- "May reduce eye strain and dry-eye symptoms."
- "Supports healthier screen habits."
- "May help with comfort during long screen sessions."
- Habit language: "break habit", "comfort habit", "look-away habit".

**Banned phrasing (never appears anywhere, in any tense or derivative form):**

- "improves vision" / "better eyesight" / "fixes eyesight"
- "strengthens eye muscles"
- "clinically cures dry eye" / "cures" / "heals" / "treats" (as a medical claim)
- "reverses myopia" / "trains vision" / "vision training"
- "restores vision", "medically proven to…", any diagnosis language ("you have dry eye")

**Rules of thumb for any new copy:** describe behaviors and comfort, not medical outcomes; hedge with "may"; frame stats as habits; the app never tells the user what condition they have. All user-facing strings live in one file (`CopyStrings.swift`, §10) so they can be audited in one place. Any copy not listed in §10 must follow these rules.

---

## 3. Non-goals

- **No vision-improvement claims.** The app does not claim to improve refractive error, permanently improve vision, or "train" eyes.
- **No diagnosis.** It does not diagnose eye disease and does not replace an eye exam. The "When to get checked" panel is educational escalation copy only.
- **No camera/webcam tracking by default (and none in MVP at all).** The health benefit comes from the reminders themselves. MVP ships with zero camera code, zero camera entitlements.
- **No network access.** No analytics, telemetry, accounts, sync, or update phone-home. Everything local.
- **No punitive enforcement in MVP.** No un-skippable breaks, no snooze limits, no shame copy. (A "strict mode" is a post-MVP option, §7.)
- **No cross-device companion app**, no website blocking, no screen-time policing.
- Not a Pomodoro/productivity tool; it never frames breaks as productivity optimization.

---

## 4. User stories with acceptance criteria

**US-1 — Core break loop.** As a developer, I want a reminder every 20 minutes to look ~20 feet away for 20 seconds, so I build the habit without thinking about it.
- AC: With default settings, 20 minutes of active use after launch produces a full-screen dim overlay with a 20-second countdown and gentle copy.
- AC: When the countdown reaches zero the overlay fades out on its own, and the work timer restarts at 20:00.
- AC: The break is recorded as "completed" in today's stats.

**US-2 — Snooze.** As a user mid-thought, I want to snooze a break for a few minutes, so the app works with my flow instead of against it.
- AC: The overlay shows a snooze button (default label "Snooze 3 min"; duration configurable 1–15 min).
- AC: Snoozing hides the overlay immediately; the prompt reappears after the snooze duration.
- AC: Snoozing is unlimited and never changes the app's tone. A break that is snoozed and later completed counts as completed.

**US-3 — Skip.** As a user in a genuine crunch, I want to skip a break entirely with one key.
- AC: Pressing Escape or clicking "Skip" dismisses the overlay instantly and restarts the full work interval.
- AC: The break is recorded as "skipped". No warning, no guilt copy, ever.

**US-4 — Menu bar presence.** As a user, I want to see time-to-next-break at a glance and control the app from the menu bar.
- AC: A status item shows a countdown (e.g. "14m") or an icon-only mode (toggle in settings).
- AC: The menu contains: Take a Break Now, Pause (30 min / 1 hour / until re-enabled) or Resume, Quiet Mode toggle, Settings…, Stats…, When to Get Checked…, Quit.
- AC: "Take a Break Now" shows the overlay immediately and, on completion, restarts the full interval.
- AC: The app has no Dock icon and no main window at launch (`LSUIElement`).

**US-5 — Quiet mode (manual).** As a user about to present, I want to silence breaks for a fixed period.
- AC: Pause for 30 min / 1 hr / until re-enabled is available from the menu.
- AC: While paused, no overlays or banners appear; the status item indicates the paused state.
- AC: Timed pauses auto-resume with a fresh full work interval; "until re-enabled" persists across app restarts.

**US-6 — Quiet mode (automatic).** As a user on a call or in a full-screen app, I want breaks suppressed automatically (best effort).
- AC: If, at the moment a break is due, another app is full-screen or the screen is being mirrored/shared (as detectable via NSScreen/CGDisplay APIs), the overlay is deferred; the app re-checks every 30 s and prompts as soon as the condition clears.
- AC: Each auto-suppression source (full-screen detection, mirroring/sharing detection) can be toggled off in Settings.
- AC: Deferral is visible in the status item ("waiting" state), so suppression never looks like a hang.
- AC: This is explicitly best-effort; missed detection must fail toward showing the break, never toward crashing or freezing.

**US-7 — Idle awareness.** As a user who steps away, I don't want a break prompt waiting on my screen when I return, and I don't want credit for breaks I didn't take at my desk.
- AC: If no keyboard/mouse input for more than the idle threshold (default 5 min, configurable 1–30 min), the work timer resets and no prompt fires while idle.
- AC: On return from idle (or wake from sleep longer than the threshold), a fresh full work interval starts.
- AC: Idle time during an already-showing break overlay does not cancel the break (looking away from the screen is the point).

**US-8 — Custom intervals.** As a user, I want to tune interval lengths while keeping 20-20-20 the obvious default.
- AC: Settings expose work interval (5–120 min), break length (10–120 s), snooze (1–15 min).
- AC: A one-click "20-20-20 (recommended)" preset restores 20 min / 20 s defaults.
- AC: Changes apply to the next cycle without restarting the app.

**US-9 — Secondary reminders.** As a user with dryness, I want optional extra nudges, each individually toggleable.
- AC: Four reminder types exist: blink, daily warm compress, artificial tears, environment (glare / airflow). Each has its own on/off toggle.
- AC: Defaults: blink ON; warm compress OFF; artificial tears OFF; environment OFF.
- AC: Secondary reminders appear as small transient banner windows (own NSWindow, auto-dismiss ~10 s, click to dismiss), never full-screen, and never interrupt typing focus.
- AC: The artificial-tears reminder includes the preservative-free note (§10). All copy matches §10 verbatim.
- AC: Secondary reminders respect quiet mode and idle state exactly like main breaks (suppressed, not queued up).

**US-10 — Stats as comfort habits.** As a user, I want to see my habit forming, without medical framing.
- AC: Stats window shows: today's breaks completed and skipped, adherence % (completed ÷ prompted), and current streak of consecutive days with ≥80% adherence (days with fewer than 3 prompted breaks don't break or extend the streak).
- AC: All framing is habit/comfort language ("Comfort habits", never symptom or outcome claims).
- AC: Data is stored locally only (JSON in Application Support). No network calls exist anywhere in the binary.

**US-11 — When to get checked.** As a user with persistent symptoms, I want honest guidance about when an app is not enough.
- AC: A menu item opens a panel with the verbatim escalation copy from §10: seek care for pain, light sensitivity, discharge, sudden vision changes, or symptoms persisting despite breaks and lubrication.
- AC: The itch/allergy note (trigger avoidance; antihistamine drops such as ketotifen) is present and explicitly labeled educational information, not personalized medical advice.

**US-12 — Launch at login.** As a habit-building user, I want the app to just be there.
- AC: A Settings toggle registers/unregisters via `SMAppService.mainApp`.
- AC: When running outside a proper .app bundle (bare `swift run` executable), the toggle is disabled with an explanatory caption (§10) instead of failing silently.

**US-13 — Open-source buildability.** As a contributor, I want to build and run with stock tools.
- AC: `swift build` succeeds on macOS 13+ with Xcode command-line tools only (no `.xcodeproj`).
- AC: `scripts/make_app.sh` produces a runnable `EyeBreak.app` with correct `Info.plist` (`LSUIElement = true`).
- AC: README explains both paths.

---

## 5. MVP feature spec (prioritized)

Priorities: **P0** = MVP core, build first. **P1** = MVP complete, ship-blocking. **P2** = MVP polish, ship-blocking but last.

### P0-1: 20-20-20 break engine
- Work interval countdown → break prompt → break countdown → repeat. Defaults: 20 min work, 20 s break.
- Per-break actions: **done** (automatic at countdown end), **snooze** (configurable, default 3 min), **skip** (Escape or button).
- Driven by the state machine in §8.4. All timer logic must be a pure, injectable-clock state machine so it is unit-testable.
- Timers must survive: display sleep, system sleep/wake (see wake handling, §8.4), clock changes (use monotonic deadlines, not wall-clock).

### P0-2: Break overlay UX
- Non-punitive **dim overlay**: borderless `NSWindow` per screen at `.screenSaver` level, covering the full screen, semi-transparent dark backdrop (≈75% opacity black; respects Reduce Transparency by going fully opaque dark gray), content centered on the main screen only, other screens dimmed blank.
- This is deliberately overlay-based, **not** Notification Center–based: it works from a bare SPM executable with no notification entitlements or app-bundle requirements.
- Sequence: 2 s fade-in (grace period — a click anywhere except buttons does nothing; typing is blocked by the overlay taking key focus) → 20 s countdown with copy (§10) → gentle completion line for 1.5 s → fade out.
- Controls: "Snooze 3 min" button, "Skip" button, **Escape always skips**. Buttons are keyboard-focusable. No sounds in MVP (silent by default).
- Copy on overlay (verbatim in §10): look ~20 feet away + relaxed blinks.
- Overlay must never steal focus in a way that loses user keystrokes into another app after dismissal; restore the previously active app on fade-out.
- Multi-display: overlay windows on all screens; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` so it appears over full-screen Spaces when a break is *not* suppressed. Rebuild windows on screen-configuration change notifications.

### P0-3: Menu bar UI
- `NSStatusItem` (AppKit) with:
  - Title: compact countdown "14m" (or eye icon only, per setting). States: countdown / "…" while on break / pause glyph while paused / "wait" glyph while deferred by quiet detection.
  - Menu: `Take a Break Now`, pause submenu (`Pause for 30 Minutes`, `Pause for 1 Hour`, `Pause Until Re-enabled`) or `Resume` when paused, `Settings…`, `Stats…`, `When to Get Checked…`, `Quit EyeBreak`. Exact strings in §10.
- Settings and Stats open as regular `NSWindow`s hosting SwiftUI views (`NSHostingController`); app remains `LSUIElement` (activate app transiently to show windows).

### P0-4: Idle detection
- Poll `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: kCGAnyInputEventType)` every 10 s (kCGAnyInputEventType is `CGEventType(rawValue: ~0)`; wrap in a helper). No Accessibility permission is needed for this API.
- Idle > threshold (default 300 s) while working/snoozed → `idleDetected` event: timer resets, state `idle`, no prompts.
- Any input while idle → `activityResumed`: fresh full work interval.
- Wake-from-sleep handling via `NSWorkspace.shared.notificationCenter` (`didWakeNotification`): if asleep longer than idle threshold, treat as idle→resume (fresh interval).

### P0-5: Custom intervals with 20-20-20 preset
- Settings sliders/steppers: work 5–120 min, break 10–120 s, snooze 1–15 min, idle threshold 1–30 min.
- "20-20-20 (recommended)" preset button restores work/break defaults. The preset is the default state on first launch.

### P1-1: Quiet mode — manual
- Menu actions: pause 30 min / 1 hour / until re-enabled. Timed pause stores a monotonic deadline; expiry auto-resumes with a fresh interval. "Until re-enabled" persists in settings across restarts.
- Pausing while an overlay is visible dismisses it and records a skip.

### P1-2: Quiet mode — automatic (best effort)
- At prompt time (and every 30 s while deferred), check:
  1. **Full-screen app**: frontmost app's key window occupies an entire screen frame — detect via `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)`, find the frontmost app's topmost window (`NSWorkspace.shared.frontmostApplication` PID), compare its bounds to any `NSScreen.frame`. Skip check when EyeBreak itself is frontmost.
  2. **Mirroring/sharing**: any active display where `CGDisplayIsInMirrorSet(displayID) != 0`, or more than one active display sharing the same bounds; plus `NSScreen`'s capture hints where available. Screen-*capture* detection on modern macOS is unreliable without extra permissions — implement mirroring detection, treat capture detection as best-effort, and document the limitation in README.
- If any enabled check is positive → defer (state stays working with a "waiting" flag), never skip silently; prompt fires as soon as checks clear.
- Two independent settings toggles: "Hold breaks while an app is full screen" (default ON), "Hold breaks while the screen is mirrored or shared" (default ON).
- Failure policy: if any API call fails, assume NOT quiet (show the break).

### P1-3: Stats (local only)
- Per-day record: date (local calendar day), promptedCount, completedCount, skippedCount, snoozeCount.
- Adherence = completed ÷ prompted (prompted = completed + skipped). Streak = consecutive days ending today (or yesterday if today has <3 prompted) with adherence ≥ 80% **and** ≥3 prompted breaks; days with <3 prompted breaks are neutral (don't break, don't extend).
- Storage: JSON file `stats.json` in `~/Library/Application Support/EyeBreak/` (create directory on first run). Atomic writes. Keep last 365 days, prune older.
- Stats window: today's completed/skipped, adherence %, streak, and a simple 14-day bar list. Header framing (§10): comfort habits only. No goals, no red colors for "bad" days.
- **No network, no analytics, ever.** Also persist stats writes on app termination.

### P1-4: Secondary reminders (individually toggleable)
- Delivery: small transient banner — a ~340×80 pt borderless `NSWindow` at `.statusBar` level, top-right of the main screen, fade in, auto-dismiss after 10 s or on click. Not Notification Center (no entitlement dependency). Banners never appear during breaks, while paused/quiet-deferred, or while idle; a due banner in those states is dropped, not queued.
- Types, defaults, schedule:
  1. **Blink reminder** — default **ON**. Every 10 min of active (non-idle) screen time, offset so it never fires within 3 min of a main break. Copy §10.
  2. **Warm-compress reminder** — default OFF. Once daily at a user-set time (default 21:00). Copy §10.
  3. **Artificial-tears reminder** — default OFF. Every 2 h of active use (configurable 1–4 h). Includes preservative-free note. Copy §10.
  4. **Environment reminders** — default OFF. One per day (default 14:00), alternating glare / airflow tips. Copy §10.
- Each type has its own toggle in a "Extra reminders (optional)" settings section, described with conservative copy.

### P1-5: "When to get checked" panel
- Static SwiftUI view opened from the menu. Verbatim copy in §10. Contains: escalation list (pain, light sensitivity, discharge, sudden vision changes, persistent symptoms despite breaks and lubrication → see an eye-care professional), the itch/allergy educational note (trigger avoidance; antihistamine drops such as ketotifen; explicitly not personalized medical advice), and the app's global non-diagnosis disclaimer.

### P1-6: Launch at login
- Settings toggle → `SMAppService.mainApp.register()` / `.unregister()` (macOS 13+ API).
- Detect bundle context: if `Bundle.main.bundleURL.pathExtension != "app"`, disable the toggle and show the caption from §10 (works only from the .app bundle).

### P2-1: Onboarding-lite
- First launch: single small welcome window (not full screen): one paragraph (§10), the 20-20-20 default named, buttons "Start" and "Open Settings". No permission requests (none are needed).

### P2-2: Polish
- Respect `NSWorkspace.accessibilityDisplayShouldReduceMotion` (no fades, instant show/hide) and Reduce Transparency.
- Dark/light adaptive banner and settings styling (overlay is inherently dark).
- Status item countdown updates at most once per minute (once per second only during the final minute) to keep CPU negligible. Target: <1% CPU idle, no timers firing more than once per 10 s in steady state.

---

## 6. Explicitly out of MVP (deliberate LookAway-pattern omissions)

Included-from-LookAway vs dropped is summarized here so the builder doesn't "helpfully" add them:

- **Dropped from MVP** (some return in §7): pre-break heads-up notification with incremental snooze chips, cursor-following floating countdown, custom break backgrounds/sounds/motivational messages, per-app exclusion lists, video/microphone-based call detection, per-session snooze limits ("strict"), planned/scheduled breaks at fixed times, iPhone companion/sync, Screen Score/website stats, AppleScript & Shortcuts automation, Focus Filter integration, posture reminders, paid licensing.
- **Kept (reimplemented independently)**: 20-20-20 engine with snooze/skip, menu-bar-first live status, quiet auto-pause (full-screen + mirroring, simplified), idle pause/reset, custom intervals, blink nudges, local stats.

---

## 7. Post-MVP roadmap (do not build now)

1. **Schedules** — active hours (e.g. 9:00–18:00), workdays only; planned fixed-time breaks.
2. **Per-app exclusions** — user-picked apps whose frontmost/full-screen status always defers breaks (e.g. Keynote, games, video editors).
3. **Strict mode** — optional: overlay without skip button, snooze cap per session. Must remain opt-in and reversible; copy stays non-punitive.
4. **Pre-break heads-up** — small 30 s warning banner with "+1m/+5m" quick snooze before the overlay.
5. **Posture / hydration reminders** — same banner infrastructure; same conservative copy rules.
6. **Localization** — copy strings are already centralized; add `Localizable.strings` extraction.
7. **Sounds** — optional gentle chime at break start/end, off by default.
8. **Shortcuts/AppleScript hooks** — "break started/ended" automation events.
9. **Sparkle or GitHub-releases update checker** — must be opt-in (it's a network call).

---

## 8. Technical architecture

### 8.1 Platform decisions

- **Language/UI**: Swift 5.9+, SwiftUI for view content, AppKit for windows/status item. Target **macOS 13+**.
- **Menu bar**: use **`NSStatusItem` + `NSMenu` (AppKit), not `MenuBarExtra`**. Rationale: an SPM executable with an `NSApplicationDelegate` main gives full control over activation policy (`.accessory`), window lifecycle, and status-item title updates without SwiftUI-App-lifecycle friction. SwiftUI is still used inside windows via `NSHostingController`/`NSHostingView`.
- **Packaging**: SwiftPM **executable target only** — no Xcode project. `swift build` / `swift run` must work from a clean checkout with Xcode CLT.
- **App bundle**: `scripts/make_app.sh` copies the release binary into `EyeBreak.app/Contents/MacOS/`, writes `Info.plist` from a template in `Resources/` with `LSUIElement = true` (no Dock icon), `CFBundleIdentifier = dev.eyebreak.EyeBreak` (placeholder — any reverse-DNS id works), min system version 13.0. Ad-hoc codesign (`codesign --force --sign - EyeBreak.app`) so `SMAppService` and TCC behave. README documents both `swift run` (dev, some features degraded: launch-at-login disabled) and bundle mode (full).
- **Persistence**: Codable JSON (`settings.json`, `stats.json`) in `~/Library/Application Support/EyeBreak/`. Chosen over UserDefaults for auditability (user can read/edit the files) and because the bundle id may vary between bare-executable and .app runs. Atomic writes; tolerate missing/corrupt files by regenerating defaults (log to stderr, never crash).
- **Concurrency**: main-thread app; timers via `DispatchSourceTimer` on the main queue with monotonic deadlines. No async/await needed; keep it simple.
- **Dependencies**: none. Zero third-party packages.
- **Entitlements/permissions**: none required. Idle detection via `CGEventSource.secondsSinceLastEventType` needs no Accessibility permission. Never request camera, notifications, screen recording, or network.

### 8.2 Module breakdown

```
Sources/EyeBreak/
├── main.swift                     // NSApplication bootstrap, .accessory policy, AppDelegate
├── AppDelegate.swift              // wires modules together, owns lifecycles
├── Core/
│   ├── BreakScheduler.swift       // pure state machine (§8.4) + Clock protocol
│   ├── SchedulerDriver.swift      // real timers; feeds events into BreakScheduler, executes effects
│   ├── IdleMonitor.swift          // CGEventSource polling + wake notifications → events
│   └── QuietModeMonitor.swift     // full-screen + mirroring checks (§5 P1-2)
├── UI/
│   ├── MenuBarController.swift    // NSStatusItem, menu, countdown title
│   ├── OverlayWindowController.swift  // per-screen overlay windows, fade, key handling
│   ├── BannerWindowController.swift   // secondary-reminder banners
│   └── Views/
│       ├── OverlayView.swift      // SwiftUI break content (countdown, buttons)
│       ├── SettingsView.swift
│       ├── StatsView.swift
│       ├── WhenToGetCheckedView.swift
│       └── WelcomeView.swift
├── Reminders/
│   └── SecondaryReminders.swift   // scheduling for blink/compress/tears/environment
├── Storage/
│   ├── SettingsStore.swift        // Codable Settings, load/save, change notifications
│   └── StatsStore.swift           // Codable day records, adherence + streak computation
└── CopyStrings.swift              // ALL user-facing strings, verbatim from §10
```

Design rules:
- `BreakScheduler` is a **pure value-type state machine**: `mutating func handle(_ event: Event, now: TimeInterval) -> [Effect]`. No Foundation timers, no AppKit imports. Fully unit-tested (`Tests/EyeBreakTests/BreakSchedulerTests.swift`, plus `StatsStoreTests.swift` for adherence/streak math).
- `SchedulerDriver` owns real time: schedules a `DispatchSourceTimer` for the next deadline the state machine reports, translates UI/monitor callbacks into events, and executes effects (`showOverlay`, `hideOverlay(reason:)`, `recordCompleted`, `recordSkipped`, `updateStatusItem`, …).
- UI classes never mutate scheduler state directly; they emit events.
- `SettingsStore` publishes changes (Combine `ObservableObject` is fine since views are SwiftUI); scheduler picks up new durations at next transition.

### 8.3 Settings schema (Codable, with defaults)

```swift
struct Settings: Codable {
  var workIntervalSec: Int = 1200        // 5–120 min
  var breakDurationSec: Int = 20         // 10–120 s
  var snoozeDurationSec: Int = 180       // 1–15 min
  var idleThresholdSec: Int = 300        // 1–30 min
  var showCountdownInMenuBar: Bool = true
  var pauseUntilReenabled: Bool = false  // persisted manual quiet mode
  var quietOnFullScreen: Bool = true
  var quietOnScreenSharing: Bool = true
  var blinkReminderOn: Bool = true
  var blinkIntervalSec: Int = 600
  var warmCompressOn: Bool = false
  var warmCompressTime: String = "21:00" // "HH:mm" local
  var tearsReminderOn: Bool = false
  var tearsIntervalSec: Int = 7200       // 1–4 h
  var environmentRemindersOn: Bool = false
  var environmentTime: String = "14:00"
  var launchAtLogin: Bool = false
  var hasCompletedWelcome: Bool = false
}
```

### 8.4 Break state machine (normative)

**States**
- `working(deadline)` — counting down to next prompt. Sub-flag `deferred` when quiet checks are holding a due break.
- `prompting` — overlay fading in (2 s grace).
- `onBreak(deadline)` — overlay countdown running.
- `snoozed(deadline)` — like working, but with snooze duration; snooze count tracked per pending break.
- `paused(kind)` — `manual(until: deadline?)` (nil = until re-enabled) — timers frozen.
- `idle` — user away; no deadline pending.

**Events** — `timerFired`, `breakCompleted` (break countdown reached 0), `snoozed`, `skipped` (button or Escape), `paused(kind)`, `resumed`, `idleDetected`, `activityResumed`, plus internal `graceElapsed`, `quietCheckPassed`/`quietCheckFailed`, `takeBreakNow`, `settingsChanged`, `systemWoke(sleepDuration)`.

**Transition table**

| State | Event | Next state | Effects |
|---|---|---|---|
| working | timerFired (deadline hit) | prompting *if quiet checks pass* | showOverlay; incrementPrompted |
| working | timerFired, quiet check fails | working(deferred) | statusItem→waiting; schedule re-check in 30 s |
| working(deferred) | quietCheckPassed | prompting | showOverlay; incrementPrompted |
| working(deferred) | quietCheckFailed | working(deferred) | re-check in 30 s |
| working / working(deferred) | idleDetected | idle | statusItem→idle |
| working | takeBreakNow | prompting | showOverlay; incrementPrompted (bypasses quiet checks — explicit user intent) |
| working | paused(kind) | paused | statusItem→paused |
| prompting | graceElapsed (2 s) | onBreak(now+breakDuration) | startBreakCountdown |
| prompting / onBreak | snoozed | snoozed(now+snoozeDuration) | hideOverlay; snoozeCount+1 |
| prompting / onBreak | skipped | working(now+workInterval) | hideOverlay; recordSkipped |
| prompting / onBreak | paused(kind) | paused | hideOverlay; recordSkipped |
| onBreak | breakCompleted | working(now+workInterval) | showCompletionLine→fadeOut; recordCompleted |
| onBreak | idleDetected | onBreak | *no-op — idle during a break is expected* |
| snoozed | timerFired | prompting (same quiet-check logic as working) | showOverlay (prompted already counted once per break cycle — do **not** increment again after a snooze) |
| snoozed | idleDetected | idle | statusItem→idle (pending break dropped, not recorded) |
| snoozed | paused(kind) | paused | — |
| paused(manual until t) | timerFired (t hit) | working(now+workInterval) | statusItem→countdown |
| paused | resumed | working(now+workInterval) | statusItem→countdown |
| paused | idleDetected / activityResumed | paused | no-op |
| idle | activityResumed | working(now+workInterval) | statusItem→countdown |
| any non-paused | systemWoke(sleep > idleThreshold) | working(now+workInterval) | statusItem→countdown (treat like idle round-trip) |
| any | settingsChanged | same state | apply new durations at next deadline computation; if current deadline exceeds new interval length, clamp to now+newInterval |

**Accounting rules**: `prompted` increments exactly once per break cycle (first time the overlay shows, including take-break-now; not again after snoozes). A cycle ends as exactly one of completed / skipped / dropped-by-idle (dropped counts as neither). This keeps adherence = completed ÷ (completed + skipped) honest.

**Failure policy**: any exception in quiet/idle monitors degrades to "show the break" / "assume active". Overlay creation failure logs to stderr and skips the cycle without crashing.

### 8.5 Overlay implementation notes

- One `NSWindow` per `NSScreen`: `styleMask: [.borderless]`, `level: .screenSaver`, `isOpaque: false`, `backgroundColor: .clear`, `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`, `ignoresMouseEvents: false`. Content: `NSHostingView(rootView: OverlayView(...))` on the screen with the mouse pointer; plain dim on others.
- Make the content window key (`makeKeyAndOrderFront`) so Escape arrives; monitor `keyDown` (Escape → `skipped`) via `NSEvent.addLocalMonitorForEvents`.
- Before showing, remember `NSWorkspace.shared.frontmostApplication`; after hiding, re-activate it.
- Observe `NSApplication.didChangeScreenParametersNotification` → rebuild windows if visible.

---

## 9. Repo layout, license, README

### 9.1 Repo layout

```
reduce_eye_strain/
├── LICENSE                      # MIT
├── README.md
├── Package.swift                # swift-tools-version: 5.9, single executable target "EyeBreak"
├── docs/
│   ├── USER_SPEC.md
│   └── PRD.md
├── Sources/EyeBreak/            # per §8.2
├── Tests/EyeBreakTests/
│   ├── BreakSchedulerTests.swift
│   └── StatsStoreTests.swift
├── Resources/
│   └── Info.plist.template
└── scripts/
    └── make_app.sh
```

`Package.swift` sketch: `platforms: [.macOS(.v13)]`, one `.executableTarget(name: "EyeBreak")`, one `.testTarget`. Link nothing beyond system frameworks (AppKit, SwiftUI, CoreGraphics, ServiceManagement, Combine).

### 9.2 License

MIT, standard text, copyright line: `Copyright (c) 2026 EyeBreak contributors`.

### 9.3 README outline

1. Name + one-liner: "Open-source macOS menu-bar app for 20-20-20 screen breaks. May reduce eye strain and dry-eye symptoms by supporting healthier screen habits."
2. What it does (breaks, snooze/skip, quiet mode, idle awareness, optional reminders, local stats) + screenshot placeholder.
3. What it deliberately doesn't do (§3 non-goals, verbatim health disclaimer from §10).
4. Install & build: `swift build -c release`, `scripts/make_app.sh`, drag to /Applications; dev mode via `swift run` and its limitations (no launch-at-login).
5. Privacy: local-only, no network, no analytics, no camera; where the JSON files live.
6. Configuration reference (settings table).
7. Known limitations (screen-share detection is best-effort; bare-executable mode).
8. Contributing + copy rules (link to PRD §2 — all new user-facing copy must pass the banned-phrase list).
9. License.

---

## 10. In-app copy — verbatim strings (paste into `CopyStrings.swift`)

The builder must use these strings exactly. Any additional strings must follow §2 rules.

### Overlay
- `overlayTitle` = `Time for a short break`
- `overlayBody` = `Look at something about 20 feet away.`
- `overlayBody2` = `Take a few relaxed blinks while you're at it.`
- `overlayCountdownSuffix` = `s` (rendered as "18 s")
- `overlayDoneLine` = `Nice. Back to it.`
- `overlaySnoozeButton` = `Snooze 3 min` (interpolate configured minutes: `Snooze %d min`)
- `overlaySkipButton` = `Skip (esc)`
- `overlayFootnote` = `Regular look-away breaks may reduce eye strain and dry-eye symptoms.`

### Menu bar
- `menuNextBreak` = `Next break in %@`
- `menuOnBreak` = `Break in progress`
- `menuWaitingQuiet` = `Waiting for a quiet moment`
- `menuPausedUntil` = `Paused until %@`
- `menuPaused` = `Paused`
- `menuIdle` = `Timer will restart when you're back`
- `menuTakeBreakNow` = `Take a Break Now`
- `menuPause30` = `Pause for 30 Minutes`
- `menuPause60` = `Pause for 1 Hour`
- `menuPauseIndefinite` = `Pause Until Re-enabled`
- `menuResume` = `Resume`
- `menuSettings` = `Settings…`
- `menuStats` = `Stats…`
- `menuWhenToGetChecked` = `When to Get Checked…`
- `menuQuit` = `Quit EyeBreak`

### Settings
- `settingsPresetButton` = `20-20-20 (recommended)`
- `settingsPresetCaption` = `Every 20 minutes, look about 20 feet away for 20 seconds.`
- `settingsQuietSectionTitle` = `Quiet mode`
- `settingsQuietFullScreen` = `Hold breaks while an app is full screen`
- `settingsQuietSharing` = `Hold breaks while the screen is mirrored or shared`
- `settingsQuietCaption` = `Detection is best effort. You can always pause manually from the menu bar.`
- `settingsRemindersSectionTitle` = `Extra reminders (optional)`
- `settingsBlinkToggle` = `Blink reminder`
- `settingsBlinkCaption` = `A small nudge to blink during long sessions. Screen use tends to reduce blinking.`
- `settingsCompressToggle` = `Daily warm-compress reminder`
- `settingsCompressCaption` = `A once-a-day reminder. Warm compresses are a common self-care step for dry-eye comfort.`
- `settingsTearsToggle` = `Artificial-tears reminder`
- `settingsTearsCaption` = `For people who already use lubricating drops. Preservative-free drops are recommended for frequent use.`
- `settingsEnvironmentToggle` = `Environment reminders`
- `settingsEnvironmentCaption` = `Occasional tips about glare and airflow, which can worsen dryness and strain.`
- `settingsLaunchAtLogin` = `Launch at login`
- `settingsLaunchAtLoginDisabledCaption` = `Available when EyeBreak runs from the .app bundle (see README).`

### Banners (secondary reminders)
- `bannerBlink` = `Blink check — a few relaxed blinks.`
- `bannerCompress` = `Evening wind-down: a warm compress over closed eyes is a common comfort step for dryness.`
- `bannerTears` = `If you use lubricating drops, this is a good moment. Preservative-free is recommended for frequent use.`
- `bannerGlare` = `Glare check: could tilting the screen or closing a blind cut reflections?`
- `bannerAirflow` = `Airflow check: a fan or AC blowing toward your face can dry out your eyes.`

### Stats
- `statsTitle` = `Comfort habits`
- `statsToday` = `Today: %d breaks taken, %d skipped`
- `statsAdherence` = `%d%% of prompted breaks taken`
- `statsStreak` = `%d day streak of 80%%+ breaks taken`
- `statsFootnote` = `These numbers track a habit, not a medical outcome. Data stays on this Mac.`

### When to get checked panel
- `checkedTitle` = `When to get checked`
- `checkedIntro` = `Break reminders support comfort, but some symptoms deserve professional care. See an eye-care professional if you notice:`
- `checkedBullet1` = `Eye pain`
- `checkedBullet2` = `Sensitivity to light`
- `checkedBullet3` = `Discharge from the eye`
- `checkedBullet4` = `Sudden changes in vision`
- `checkedBullet5` = `Symptoms that persist despite regular breaks and lubricating drops`
- `checkedItchNote` = `Itchy eyes are often allergy-related. Common approaches include avoiding triggers and antihistamine eye drops such as ketotifen. This is general educational information, not personalized medical advice.`
- `checkedDisclaimer` = `EyeBreak supports healthier screen habits. It does not diagnose eye disease, replace an eye exam, or improve vision.`

### Welcome (first launch)
- `welcomeTitle` = `Welcome to EyeBreak`
- `welcomeBody` = `Every 20 minutes, EyeBreak will invite you to look at something about 20 feet away for 20 seconds, with a few relaxed blinks. Regular look-away breaks may reduce eye strain and dry-eye symptoms. You can snooze or skip any break — this is a habit, not a rule.`
- `welcomeStart` = `Start`
- `welcomeSettings` = `Open Settings`

---

## 11. Success metrics (all local, all habit-framed)

No telemetry exists, so these are **self-served metrics shown to the user** and design targets for the project, not collected data:

1. **Adherence** — % of prompted breaks completed per day. Design target: defaults + non-punitive UX make ≥60% adherence sustainable; the streak threshold (80%) defines a "good day".
2. **Habit retention** — streak length of ≥80% days; target UX outcome: streaks survive real work weeks because quiet mode and idle detection prevent false prompts (prompt precision matters more than prompt volume).
3. **Non-annoyance proxies** (qualitative/GitHub): users don't disable the app to escape it — skip rate stays below snooze+complete rate; issues about "annoying" behavior are treated as P1 bugs.
4. **Performance budget** — <1% CPU idle, <60 MB memory, zero network connections (verifiable with Little Snitch/`nettop`).

All success language stays within §2: these measure a comfort habit, never a medical outcome.

---

*End of PRD. Builder agent: read `docs/USER_SPEC.md` first, then implement this document top-down by priority (P0 → P1 → P2), keeping `BreakScheduler` pure and tested before wiring UI.*
