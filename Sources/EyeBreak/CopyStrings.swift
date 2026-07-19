// All user-facing strings, verbatim from PRD §10.
// Any new copy must follow the conservative health-copy rules in PRD §2:
// describe behaviors and comfort, hedge with "may", never medical claims.

enum CopyStrings {
    // MARK: Overlay
    static let overlayTitle = "Time for a short break"
    static let overlayBody = "Look at something about 20 feet away."
    static let overlayBody2 = "Take a few relaxed blinks while you're at it."
    static let overlayCountdownSuffix = "s"
    static let overlayDoneLine = "Nice. Back to it."
    static let overlaySnoozeButton = "Snooze %d min"
    static let overlaySkipButton = "Skip (esc)"
    static let overlayFootnote = "Regular look-away breaks may reduce eye strain and dry-eye symptoms."

    // MARK: Menu bar
    static let menuNextBreak = "Next break in %@"
    static let menuOnBreak = "Break in progress"
    static let menuWaitingQuiet = "Waiting for a quiet moment"
    static let menuPausedUntil = "Paused until %@"
    static let menuPaused = "Paused"
    static let menuIdle = "Timer will restart when you're back"
    static let menuTakeBreakNow = "Take a Break Now"
    static let menuPause30 = "Pause for 30 Minutes"
    static let menuPause60 = "Pause for 1 Hour"
    static let menuPauseIndefinite = "Pause Until Re-enabled"
    static let menuResume = "Resume"
    static let menuSettings = "Settings…"
    static let menuStats = "Stats…"
    static let menuWhenToGetChecked = "When to Get Checked…"
    static let menuQuit = "Quit EyeBreak"

    // MARK: Settings
    static let settingsPresetButton = "20-20-20 (recommended)"
    static let settingsPresetCaption = "Every 20 minutes, look about 20 feet away for 20 seconds."
    static let settingsQuietSectionTitle = "Quiet mode"
    static let settingsQuietFullScreen = "Hold breaks while an app is full screen"
    static let settingsQuietSharing = "Hold breaks while the screen is mirrored or shared"
    static let settingsQuietCaption = "Detection is best effort. You can always pause manually from the menu bar."
    static let settingsRemindersSectionTitle = "Extra reminders (optional)"
    static let settingsBlinkToggle = "Blink reminder"
    static let settingsBlinkCaption = "A small nudge to blink during long sessions. Screen use tends to reduce blinking."
    static let settingsCompressToggle = "Daily warm-compress reminder"
    static let settingsCompressCaption = "A once-a-day reminder. Warm compresses are a common self-care step for dry-eye comfort."
    static let settingsTearsToggle = "Artificial-tears reminder"
    static let settingsTearsCaption = "For people who already use lubricating drops. Preservative-free drops are recommended for frequent use."
    static let settingsEnvironmentToggle = "Environment reminders"
    static let settingsEnvironmentCaption = "Occasional tips about glare and airflow, which can worsen dryness and strain."
    static let settingsLaunchAtLogin = "Launch at login"
    static let settingsLaunchAtLoginDisabledCaption = "Available when EyeBreak runs from the .app bundle (see README)."

    // MARK: Banners (secondary reminders)
    static let bannerBlink = "Blink check — a few relaxed blinks."
    static let bannerCompress = "Evening wind-down: a warm compress over closed eyes is a common comfort step for dryness."
    static let bannerTears = "If you use lubricating drops, this is a good moment. Preservative-free is recommended for frequent use."
    static let bannerGlare = "Glare check: could tilting the screen or closing a blind cut reflections?"
    static let bannerAirflow = "Airflow check: a fan or AC blowing toward your face can dry out your eyes."

    // MARK: Stats
    static let statsTitle = "Comfort habits"
    static let statsToday = "Today: %d breaks taken, %d skipped"
    static let statsAdherence = "%d%% of prompted breaks taken"
    static let statsStreak = "%d day streak of 80%%+ breaks taken"
    static let statsFootnote = "These numbers track a habit, not a medical outcome. Data stays on this Mac."

    // MARK: When to get checked panel
    static let checkedTitle = "When to get checked"
    static let checkedIntro = "Break reminders support comfort, but some symptoms deserve professional care. See an eye-care professional if you notice:"
    static let checkedBullet1 = "Eye pain"
    static let checkedBullet2 = "Sensitivity to light"
    static let checkedBullet3 = "Discharge from the eye"
    static let checkedBullet4 = "Sudden changes in vision"
    static let checkedBullet5 = "Symptoms that persist despite regular breaks and lubricating drops"
    static let checkedItchNote = "Itchy eyes are often allergy-related. Common approaches include avoiding triggers and antihistamine eye drops such as ketotifen. This is general educational information, not personalized medical advice."
    static let checkedDisclaimer = "EyeBreak supports healthier screen habits. It does not diagnose eye disease, replace an eye exam, or improve vision."

    // MARK: Welcome (first launch)
    static let welcomeTitle = "Welcome to EyeBreak"
    static let welcomeBody = "Every 20 minutes, EyeBreak will invite you to look at something about 20 feet away for 20 seconds, with a few relaxed blinks. Regular look-away breaks may reduce eye strain and dry-eye symptoms. You can snooze or skip any break — this is a habit, not a rule."
    static let welcomeStart = "Start"
    static let welcomeSettings = "Open Settings"
}
