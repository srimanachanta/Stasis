import SwiftUI

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var showPercentage: Bool = false

    private enum Layout {
        static let batteryHeight: CGFloat = 12
        static let batteryWidth: CGFloat = 24
        static let terminalWidth: CGFloat = 2
        static let terminalHeight: CGFloat = 5
        static let cornerRadius: CGFloat = 3
        static let strokeWidth: CGFloat = 1
        static let fillInset: CGFloat = 1.5
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(.primary.opacity(0.25))

                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .stroke(lineWidth: Layout.strokeWidth)
                    .opacity(0.4)

                GeometryReader { geo in
                    let fillWidth =
                        (geo.size.width - Layout.fillInset * 2)
                        * CGFloat(batteryLevel)
                        / 100
                    RoundedRectangle(
                        cornerRadius: Layout.cornerRadius - Layout.fillInset
                    )
                    .fill(.primary)
                    .frame(width: max(0, fillWidth))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Layout.fillInset)
                }

                HStack(spacing: 1) {
                    if chargingMode == .charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 5, weight: .medium))
                    } else if chargingMode == .pluggedIn {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 5, weight: .medium))
                            .rotationEffect(.degrees(-90))
                    }

                    if showPercentage {
                        Text("\(batteryLevel)")
                            .font(.system(size: 9, weight: .medium))
                            .monospacedDigit()
                    }
                }.colorInvert()

            }
            .frame(width: Layout.batteryWidth, height: Layout.batteryHeight)

            BatteryTerminal(
                width: Layout.terminalWidth,
                height: Layout.terminalHeight,
                cornerRadius: 1.25
            )
        }
        .foregroundStyle(.primary)
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
        // Simulate menu bar appearance
        ForEach([100, 80, 50, 20, 10, 5], id: \.self) { level in
            HStack(spacing: 20) {
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .discharging
                )
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .charging
                )
                BatteryIndicatorView(
                    batteryLevel: level,
                    chargingMode: .pluggedIn
                )
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
