# EyeBreak

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Dependencies: none](https://img.shields.io/badge/dependencies-none-lightgrey)
![Network: none](https://img.shields.io/badge/network-none-lightgrey)

**Version:** 0.2.0

Open-source macOS menu-bar app for 20-20-20 screen breaks — a free, open-source alternative to apps like [LookAway](https://lookaway.com/). May reduce eye strain and dry-eye symptoms by supporting healthier screen habits.

EyeBreak lives in your menu bar and, every 20 minutes, invites you to look at something about 20 feet away for 20 seconds — with a few relaxed blinks. You can snooze or skip any break; this is a habit, not a rule.

## What it does

- **20-20-20 breaks** — a gentle full-screen dim overlay with a countdown. Defaults: 20 minutes of work, 20 seconds of break. Fully configurable (work 5–120 min, break 10–120 s, snooze 1–15 min), with a one-click "20-20-20 (recommended)" preset.
- **Snooze and skip, never punished** — snooze is unlimited; Escape always skips. No warnings, no guilt copy.
- **Menu-bar countdown** — see time to the next break at a glance (or icon-only mode). Take a break now, pause for 30 min / 1 hour / until re-enabled.
- **Quiet mode (automatic, best effort)** — breaks are held while another app is full screen or the screen is mirrored, and shown as soon as the coast is clear. Each detection can be toggled off.
- **Idle awareness** — step away and the timer resets; no prompt waits on your screen, and breaks you didn't take at your desk are never counted.
- **Optional extra reminders** (each individually toggleable, all off by default except blink): blink nudges, a daily warm-compress reminder, an artificial-tears reminder (with a preservative-free note), and occasional glare/airflow tips.
- **Local habit stats** — breaks taken and skipped today, adherence, and a streak of 80%+ days. Framed as comfort habits, stored only on your Mac.

## What it deliberately doesn't do

- **No vision-improvement claims.** EyeBreak does not claim to improve refractive error, permanently improve vision, or "train" eyes. The well-supported benefit of look-away breaks is comfort and symptom reduction, not prescription change.
- **No diagnosis.** It does not diagnose eye disease and does not replace an eye exam.
- **No camera.** Zero camera code, zero camera entitlements. The benefit comes from the reminders themselves.
- **No network.** No analytics, telemetry, accounts, sync, or update phone-home. Everything is local.
- **No punitive enforcement.** No un-skippable breaks, no snooze limits, no shame copy.
- Not a Pomodoro/productivity tool.

> EyeBreak supports healthier screen habits. It does not diagnose eye disease, replace an eye exam, or improve vision.

## Install

### Homebrew (recommended)

```sh
brew tap sviatil0/tap
brew install --cask eyebreak
```

### Direct download

Grab `EyeBreak-x.y.z.zip` from the [latest release](https://github.com/sviatil0/eyebreak/releases/latest), unzip, and drag `EyeBreak.app` into `/Applications`.

> **First launch:** EyeBreak is ad-hoc signed, not notarized (no paid Apple Developer account — it's a free open-source app). macOS will block the first launch; allow it via **System Settings → Privacy & Security → Open Anyway**, or install with `brew install --cask --no-quarantine eyebreak`. The source is right here if you'd rather build it yourself:

### Build from source

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`). No Xcode project, no third-party dependencies.

```sh
git clone https://github.com/sviatil0/eyebreak.git
cd eyebreak

# Build the app bundle and put it wherever you like:
scripts/make_app.sh          # produces dist/EyeBreak.app (ad-hoc signed)
open dist/EyeBreak.app       # or drag it into /Applications
```

Dev mode:

```sh
swift build        # compile
swift test         # run the state-machine and stats unit tests
swift run          # run as a bare executable
```

Bare `swift run` mode is fully functional except **launch at login**, which requires a real `.app` bundle (the toggle is disabled with an explanatory caption).

## Privacy

- Everything stays on your Mac. There are no network calls anywhere in the binary — verifiable with Little Snitch or `nettop`.
- Settings and stats are plain JSON you can read and edit:
  `~/Library/Application Support/EyeBreak/settings.json` and `stats.json`.
- No permissions are requested: idle detection uses `CGEventSource`, which needs no Accessibility access; there are no notification, camera, or screen-recording entitlements.

## Configuration reference

| Setting | Range | Default |
|---|---|---|
| Work interval | 5–120 min | 20 min |
| Break length | 10–120 s | 20 s |
| Snooze | 1–15 min | 3 min |
| Idle threshold | 1–30 min | 5 min |
| Show countdown in menu bar | on/off | on |
| Hold breaks while an app is full screen | on/off | on |
| Hold breaks while the screen is mirrored or shared | on/off | on |
| Blink reminder | on/off, every 10 min of active use | on |
| Daily warm-compress reminder | on/off, at a set time | off (21:00) |
| Artificial-tears reminder | on/off, every 1–4 h of active use | off (2 h) |
| Environment reminders | on/off, once daily | off (14:00) |
| Launch at login | on/off (requires .app bundle) | off |

## When to get checked

Break reminders support comfort, but some symptoms deserve professional care. See an eye-care professional if you notice eye pain, sensitivity to light, discharge from the eye, sudden changes in vision, or symptoms that persist despite regular breaks and lubricating drops. The in-app "When to Get Checked…" panel has the details, including an educational note about allergy-type itch (this is general information, not personalized medical advice).

## Known limitations

- **Screen-share detection is best effort.** EyeBreak detects display *mirroring* via CoreGraphics. Detecting active screen *capture* (e.g. a video call sharing your screen) is unreliable on modern macOS without extra permissions, so it is not attempted. Any detection failure fails toward *showing* the break, never toward silently suppressing it. You can always pause manually from the menu bar.
- **Full-screen detection is heuristic** (frontmost app's topmost window covering a screen). Some apps may not be detected; the same fail-open policy applies.
- **Bare-executable mode** (`swift run`) cannot register launch-at-login; use the `.app` bundle from `scripts/make_app.sh`.
- Daily reminders (warm compress, environment) track their "already fired today" state in memory, so restarting the app within the reminder hour could show one twice.

## Contributing

Issues and PRs welcome. Two house rules:

1. **Copy rules are strict.** All user-facing strings live in `Sources/EyeBreak/CopyStrings.swift`, and any new copy must follow the conservative health-copy rules in `docs/PRD.md` §2: describe behaviors and comfort, hedge with "may", and never use the banned phrases (vision improvement, eye-muscle strengthening, cure/treat claims, diagnosis language).
2. **Local-only stays local-only.** No network code, no analytics, no telemetry — including in dependencies (there are none, and we'd like to keep it that way).

Reports that EyeBreak feels annoying or naggy are treated as priority bugs, not feature requests.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 EyeBreak contributors.
