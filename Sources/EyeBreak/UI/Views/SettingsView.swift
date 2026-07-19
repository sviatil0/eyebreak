import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    // Launch-at-login needs a real .app bundle; bare `swift run` executables
    // can't register with SMAppService (PRD P1-6).
    private let runningFromBundle = Bundle.main.bundleURL.pathExtension == "app"

    var body: some View {
        Form {
            intervalsSection
            Divider()
            quietSection
            Divider()
            remindersSection
            Divider()
            generalSection
        }
        .padding(20)
        .frame(width: 440)
    }

    // MARK: - Intervals

    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(CopyStrings.settingsPresetButton) {
                store.settings.workIntervalSec = 1200
                store.settings.breakDurationSec = 20
                store.settings.snoozeDurationSec = 180
            }
            Text(CopyStrings.settingsPresetCaption)
                .font(.caption)
                .foregroundColor(.secondary)

            stepper(
                label: "Work interval",
                value: minutesBinding(\.workIntervalSec),
                range: 5...120, unit: "min"
            )
            stepper(
                label: "Break length",
                value: Binding(
                    get: { store.settings.breakDurationSec },
                    set: { store.settings.breakDurationSec = $0 }
                ),
                range: 10...120, unit: "s", step: 5
            )
            stepper(
                label: "Snooze",
                value: minutesBinding(\.snoozeDurationSec),
                range: 1...15, unit: "min"
            )
            stepper(
                label: "Idle threshold",
                value: minutesBinding(\.idleThresholdSec),
                range: 1...30, unit: "min"
            )
        }
    }

    // MARK: - Quiet mode

    private var quietSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CopyStrings.settingsQuietSectionTitle).font(.headline)
            Toggle(CopyStrings.settingsQuietFullScreen, isOn: $store.settings.quietOnFullScreen)
            Toggle(CopyStrings.settingsQuietSharing, isOn: $store.settings.quietOnScreenSharing)
            Text(CopyStrings.settingsQuietCaption)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Extra reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CopyStrings.settingsRemindersSectionTitle).font(.headline)

            Toggle(CopyStrings.settingsBlinkToggle, isOn: $store.settings.blinkReminderOn)
            caption(CopyStrings.settingsBlinkCaption)

            Toggle(CopyStrings.settingsCompressToggle, isOn: $store.settings.warmCompressOn)
            caption(CopyStrings.settingsCompressCaption)
            if store.settings.warmCompressOn {
                timePicker(label: "Reminder time", keyPath: \.warmCompressTime)
            }

            Toggle(CopyStrings.settingsTearsToggle, isOn: $store.settings.tearsReminderOn)
            caption(CopyStrings.settingsTearsCaption)
            if store.settings.tearsReminderOn {
                stepper(
                    label: "Every",
                    value: Binding(
                        get: { store.settings.tearsIntervalSec / 3600 },
                        set: { store.settings.tearsIntervalSec = $0 * 3600 }
                    ),
                    range: 1...4, unit: "h"
                )
            }

            Toggle(CopyStrings.settingsEnvironmentToggle, isOn: $store.settings.environmentRemindersOn)
            caption(CopyStrings.settingsEnvironmentCaption)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show countdown in menu bar", isOn: $store.settings.showCountdownInMenuBar)

            Toggle(CopyStrings.settingsLaunchAtLogin, isOn: launchAtLoginBinding)
                .disabled(!runningFromBundle)
            if !runningFromBundle {
                caption(CopyStrings.settingsLaunchAtLoginDisabledCaption)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.settings.launchAtLogin },
            set: { enabled in
                store.settings.launchAtLogin = enabled
                guard runningFromBundle else { return }
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    FileHandle.standardError.write(Data("EyeBreak: launch-at-login change failed (\(error))\n".utf8))
                    store.settings.launchAtLogin = !enabled
                }
            }
        )
    }

    // MARK: - Helpers

    private func minutesBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Int> {
        Binding(
            get: { store.settings[keyPath: keyPath] / 60 },
            set: { store.settings[keyPath: keyPath] = $0 * 60 }
        )
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, step: Int = 1) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(
                "\(value.wrappedValue) \(unit)",
                value: Binding(
                    get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
                    set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
                ),
                in: range, step: step
            )
            .frame(width: 120, alignment: .trailing)
        }
    }

    private func timePicker(label: String, keyPath: WritableKeyPath<Settings, String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { Self.date(from: store.settings[keyPath: keyPath]) },
                    set: { store.settings[keyPath: keyPath] = Self.timeString(from: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .frame(width: 90)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 2)
    }

    static func date(from hhmm: String) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts.count == 2 ? parts[0] : 21
        components.minute = parts.count == 2 ? parts[1] : 0
        return Calendar.current.date(from: components) ?? Date()
    }

    static func timeString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
