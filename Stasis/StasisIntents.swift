import AppIntents
import Defaults
import Foundation

enum StasisIntentError: LocalizedError {
    case appUnavailable

    var errorDescription: String? {
        switch self {
        case .appUnavailable:
            String(localized: "Stasis is not ready. Open Stasis and try again.")
        }
    }
}

struct SetChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Charge Limit"
    static let description = IntentDescription(
        "Sets the maximum battery charge limit in Stasis."
    )

    @Parameter(title: "Charge Limit", inclusiveRange: (50, 100))
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set charge limit to \(\.$limit)%")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let chargeManager = await AppDelegate.resolvedChargeManager() else {
            throw StasisIntentError.appUnavailable
        }
        try await chargeManager.setChargeLimit(limit)
        return .result(dialog: "Charge limit set to \(limit)%.")
    }
}

struct GetChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Charge Limit"
    static let description = IntentDescription(
        "Returns the current battery charge limit configured in Stasis."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        if let chargeManager = await AppDelegate.resolvedChargeManager() {
            await chargeManager.waitForStartup()
        }
        let limit = Defaults[.chargeLimit]
        return .result(value: limit, dialog: "Charge limit is \(limit)%.")
    }
}

struct SetChargeLimitOverrideIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Charge Limit Override"
    static let description = IntentDescription(
        "Temporarily charges to 100% or resumes enforcing your charge limit."
    )

    @Parameter(title: "Charge to Full", default: true)
    var enabled: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Set Charge Limit Override to \(\.$enabled)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let chargeManager = await AppDelegate.resolvedChargeManager() else {
            throw StasisIntentError.appUnavailable
        }
        try await chargeManager.setChargeLimitOverride(enabled: enabled)
        let dialog: IntentDialog =
            enabled ? "Charging to 100%." : "Charge limit resumed."
        return .result(dialog: dialog)
    }
}

struct SetForceDischargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Force Discharge"
    static let description = IntentDescription(
        "Stops charging and discharges the battery while plugged in, or resumes normal charging."
    )

    @Parameter(title: "Force Discharge", default: true)
    var enabled: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Set Force Discharge to \(\.$enabled)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let chargeManager = await AppDelegate.resolvedChargeManager() else {
            throw StasisIntentError.appUnavailable
        }
        try await chargeManager.setForceDischarge(enabled: enabled)
        let dialog: IntentDialog =
            enabled ? "Force discharge enabled." : "Force discharge disabled."
        return .result(dialog: dialog)
    }
}

struct StasisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetChargeLimitIntent(),
            phrases: [
                "Set charge limit in \(.applicationName)",
                "Change charge limit in \(.applicationName)",
            ],
            shortTitle: "Set Charge Limit",
            systemImageName: "battery.75percent"
        )
        AppShortcut(
            intent: SetChargeLimitOverrideIntent(),
            phrases: [
                "Charge to full with \(.applicationName)",
                "Override charge limit in \(.applicationName)",
            ],
            shortTitle: "Charge to Full",
            systemImageName: "bolt.batteryblock"
        )
        AppShortcut(
            intent: SetForceDischargeIntent(),
            phrases: [
                "Force discharge with \(.applicationName)",
                "Stop charging with \(.applicationName)",
            ],
            shortTitle: "Force Discharge",
            systemImageName: "minus.plus.batteryblock"
        )
    }
}
