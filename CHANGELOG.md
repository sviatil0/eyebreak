# Changelog

All notable changes to EyeBreak are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-07-19

Initial release.

### Added
- 20-20-20 break engine: 20 min work / 20 s break defaults, configurable intervals, snooze (default 3 min) and skip, pure state-machine core with full unit-test coverage.
- Per-screen dim overlay breaks with countdown, grace fade-in, and Escape-to-skip. No Notification Center dependency.
- Menu-bar app: live countdown status item, pause (30 min / 1 h / until re-enabled), take-break-now, settings, stats.
- Automatic quiet mode: breaks held while an app is full screen or the display is mirrored; all detection failures fail open toward showing the break.
- Idle awareness via `CGEventSource`: timer resets when you step away; missed-while-away breaks are never counted.
- Optional secondary reminders (individually toggleable): blink nudges, daily warm compress, artificial tears (preservative-free note), glare/airflow environment tips.
- Local habit stats: daily completed/skipped, adherence, streak of ≥80% days. JSON in `~/Library/Application Support/EyeBreak/`, no network anywhere.
- "When to Get Checked" safety panel with conservative, non-diagnostic health copy.
- `scripts/make_app.sh` builds a signed (ad-hoc) `EyeBreak.app` bundle with `LSUIElement` (no Dock icon); launch-at-login toggle when running from the bundle.
