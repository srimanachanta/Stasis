import SwiftUI

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool = false
    var percentageDisplayLocation: PercentageDisplayLocation = .hidden
    var showState: Bool = false

    private var shouldShowInsidePercentage: Bool {
        percentageDisplayLocation == .insideIcon
    }

    private var shouldShowOutsidePercentage: Bool {
        percentageDisplayLocation == .nextToIcon
    }

    private var isCritical: Bool {
        showState && batteryLevel <= 10
    }

    private var fillColor: Color {
        if isCritical { return .red }
        if isLowPowerModeEnabled { return .yellow }
        if chargingMode == .charging { return .green }
        return .primary
    }

    private var foregroundColor: Color {
        if isCritical { return .white }
        if isLowPowerModeEnabled { return .black }
        if chargingMode == .charging { return .white }
        return .white  // ignored when usesPassthrough
    }

    private var usesPassthrough: Bool {
        !isCritical && !isLowPowerModeEnabled && chargingMode != .charging
    }

    private var trackColor: Color {
        if isCritical { return .red }
        if isLowPowerModeEnabled { return .yellow }
        if chargingMode == .charging { return .green }
        return .primary
    }

    private enum Layout {
        static let batteryHeight: CGFloat = 12
        static let batteryWidth: CGFloat = 24
        static let insideBatteryWidth: CGFloat = 28
        static let terminalWidth: CGFloat = 2
        static let terminalHeight: CGFloat = 5
        static let cornerRadius: CGFloat = 3
        static let strokeWidth: CGFloat = 1
        static let fillInset: CGFloat = 1.5
        static let trackOpacity: CGFloat = 0.18
        static let outlineOpacity: CGFloat = 0.4
    }

    var body: some View {
        HStack(spacing: 4) {
            if shouldShowOutsidePercentage {
                Text("\(batteryLevel)%")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                batteryBody
                BatteryTerminal(
                    width: Layout.terminalWidth,
                    height: Layout.terminalHeight,
                    cornerRadius: 1.25
                )
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var batteryBody: some View {
        if shouldShowInsidePercentage {
            knockoutBatteryBody
                .frame(width: Layout.insideBatteryWidth, height: Layout.batteryHeight)
        } else {
            overlayBatteryBody
                .frame(width: Layout.batteryWidth, height: Layout.batteryHeight)
        }
    }

    private var knockoutBatteryBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(trackColor.opacity(Layout.trackOpacity))

            GeometryReader { geo in
                let fillWidth =
                    (geo.size.width - Layout.fillInset * 2)
                    * CGFloat(batteryLevel)
                    / 100
                RoundedRectangle(
                    cornerRadius: Layout.cornerRadius - Layout.fillInset
                )
                .fill(fillColor)
                .frame(width: max(0, fillWidth))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.fillInset)
            }

            insideContent

            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(lineWidth: Layout.strokeWidth)
                .opacity(Layout.outlineOpacity)
        }
        .compositingGroup()
    }

    private var insideContent: some View {
        let blend: BlendMode = usesPassthrough ? .destinationOut : .normal
        return HStack(spacing: 1) {
            Text(verbatim: "\(batteryLevel)")
                .font(.system(size: 8, weight: .heavy))
                .monospacedDigit()
            chargingGlyph
                .font(.system(size: 6, weight: .black))
        }
        .lineLimit(1)
        .foregroundStyle(foregroundColor)
        .blendMode(blend)
    }

    @ViewBuilder
    private var chargingGlyph: some View {
        if chargingMode == .charging {
            Image(systemName: "bolt.fill")
        } else if chargingMode == .pluggedIn {
            Image(systemName: "powerplug.fill")
                .rotationEffect(.degrees(-90))
        }
    }

    private var overlayBatteryBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(lineWidth: Layout.strokeWidth)
                .opacity(Layout.outlineOpacity)

            GeometryReader { geo in
                let fillWidth =
                    (geo.size.width - Layout.fillInset * 2)
                    * CGFloat(batteryLevel)
                    / 100
                RoundedRectangle(
                    cornerRadius: Layout.cornerRadius - Layout.fillInset
                )
                .fill(fillColor)
                .frame(width: max(0, fillWidth))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.fillInset)
            }
        }
        .overlay {
            if chargingMode == .charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0.5)
            } else if chargingMode == .pluggedIn {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 10, weight: .black))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0.5)
            }
        }
    }
}

struct BatteryTerminal: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: cornerRadius
        )
        .fill(.primary)
        .frame(width: width, height: height)
        .opacity(0.4)
        .offset(x: 1)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ForEach([100, 80, 50, 20, 10, 5], id: \.self) { level in
            HStack(spacing: 20) {
                BatteryIndicatorView(batteryLevel: level, chargingMode: .discharging)
                BatteryIndicatorView(batteryLevel: level, chargingMode: .charging)
                BatteryIndicatorView(batteryLevel: level, chargingMode: .pluggedIn)
            }
        }

        Divider()
        Text("Inside Icon — normal / charging / plugged")
            .font(.caption).foregroundStyle(.secondary)

        ForEach([100, 80, 50, 20, 10, 5], id: \.self) { level in
            HStack(spacing: 20) {
                BatteryIndicatorView(
                    batteryLevel: level, chargingMode: .discharging,
                    percentageDisplayLocation: .insideIcon, showState: true)
                BatteryIndicatorView(
                    batteryLevel: level, chargingMode: .charging,
                    percentageDisplayLocation: .insideIcon, showState: true)
                BatteryIndicatorView(
                    batteryLevel: level, chargingMode: .pluggedIn,
                    percentageDisplayLocation: .insideIcon, showState: true)
            }
        }

        Divider()
        Text("Inside Icon — Low Power Mode (critical red takes priority)")
            .font(.caption).foregroundStyle(.secondary)

        ForEach([100, 50, 10, 5], id: \.self) { level in
            HStack(spacing: 20) {
                BatteryIndicatorView(
                    batteryLevel: level, chargingMode: .discharging,
                    isLowPowerModeEnabled: true,
                    percentageDisplayLocation: .insideIcon, showState: true)
                BatteryIndicatorView(
                    batteryLevel: level, chargingMode: .charging,
                    isLowPowerModeEnabled: true,
                    percentageDisplayLocation: .insideIcon, showState: true)
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
