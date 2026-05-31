import SwiftUI

struct PowerSankeyView: View {
    let powerSource: PowerSource
    let isCharging: Bool
    let batteryPower: Double
    let adapterPower: Double
    let systemPower: Double
    let outputPower: Double
    let outputPortPowers: [Double]

    private var twoOutputIcons: (first: String, second: String) {
        guard outputPortPowers.count >= 2 else { return ("iphone", "display") }
        return outputPortPowers[0] >= outputPortPowers[1]
            ? ("iphone", "display")
            : ("display", "iphone")
    }

    private enum Layout {
        static let nodeWidth: CGFloat = 60
        static let gap: CGFloat = 5
        static let spacerHeight: CGFloat = 20
        static let largeNodeHeight: CGFloat = 100
        static let viewHeight: CGFloat = 125
        static let flowOpacity: Double = 0.15
        static let powerLabelSize: CGFloat = 13
        static let powerLabelSpacing: CGFloat = 45
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                flowsAndLabels

                HStack {
                    leftNodes
                    Spacer()
                    rightNodes
                }
            }
        }
        .frame(height: Layout.viewHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var flowsAndLabels: some View {
        let hasAnyOutput = outputPower > 0
        let hasTwoOutputs = outputPortPowers.count >= 2
        switch powerSource {
        case .acAdapter:
            if batteryPower > 0 {
                Canvas { context, size in
                    if outputPower > 0 {
                        drawTripleSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawSplitSankeyFlow(context: context, size: size)
                    }
                }
                VStack(spacing: outputPower > 0 ? 22 : Layout.powerLabelSpacing) {
                    PowerLabel(power: batteryPower)
                    PowerLabel(power: systemPower)
                    if outputPower > 0 {
                        PowerLabel(power: outputPower)
                    }
                }
            } else {
                Canvas { context, size in
                    if outputPortPowers.count >= 2 {
                        drawTripleSplitSankeyFlow(context: context, size: size)
                    } else if outputPower > 0 {
                        drawSplitSankeyFlow(context: context, size: size)
                    } else {
                        drawSimpleFlow(context: context, size: size)
                    }
                }
                if outputPortPowers.count >= 2 {
                    VStack(spacing: 22) {
                        PowerLabel(power: systemPower)
                        PowerLabel(power: outputPortPowers[0])
                        PowerLabel(power: outputPortPowers[1])
                    }
                } else if outputPower > 0 {
                    VStack(spacing: Layout.powerLabelSpacing) {
                        PowerLabel(power: systemPower)
                        PowerLabel(power: outputPower)
                    }
                } else {
                    PowerLabel(power: adapterPower)
                }
            }

        case .both:
            Canvas { context, size in
                drawMergeSankeyFlow(context: context, size: size)
            }
            VStack(spacing: Layout.powerLabelSpacing) {
                PowerLabel(power: batteryPower)
                PowerLabel(power: adapterPower)
            }

        case .battery:
            Canvas { context, size in
                if hasTwoOutputs {
                    drawTripleSplitSankeyFlow(context: context, size: size)
                } else if hasAnyOutput {
                    drawSplitSankeyFlow(context: context, size: size)
                } else {
                    drawSimpleFlow(context: context, size: size)
                }
            }
            if hasTwoOutputs {
                VStack(spacing: 22) {
                    PowerLabel(power: systemPower)
                    PowerLabel(power: outputPortPowers[0])
                    PowerLabel(power: outputPortPowers[1])
                }
            } else if hasAnyOutput {
                VStack(spacing: Layout.powerLabelSpacing) {
                    PowerLabel(power: systemPower)
                    PowerLabel(power: outputPower)
                }
            } else {
                PowerLabel(power: systemPower)
            }
        }
    }

    @ViewBuilder
    private var leftNodes: some View {
        let hasAnyOutput = outputPower > 0
        VStack(spacing: 0) {
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: "bolt.fill",
                        value: abs(adapterPower),
                        isLeftSide: true
                    )
                    .frame(height: Layout.largeNodeHeight)
                } else {
                    if hasAnyOutput {
                        NodeView(
                            icon: "powerplug.fill",
                            value: nil,
                            isLeftSide: true
                        )
                        .frame(height: Layout.largeNodeHeight)
                    } else {
                        NodeView(
                            icon: "powerplug.fill",
                            value: nil,
                            isLeftSide: true
                        )
                    }
                }
            case .both:
                NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                Spacer(minLength: Layout.spacerHeight)
                NodeView(icon: "powerplug.fill", value: nil, isLeftSide: true)
            case .battery:
                if hasAnyOutput {
                    NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                        .frame(height: Layout.largeNodeHeight)
                } else {
                    NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                }
            }
        }
    }

    @ViewBuilder
    private var rightNodes: some View {
        VStack(spacing: 0) {
            let hasTwoOutputs = outputPortPowers.count >= 2
            let hasAnyOutput = outputPower > 0
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: isCharging ? "battery.100.bolt" : "battery.100",
                        value: nil,
                        isLeftSide: false
                    )
                    Spacer(minLength: Layout.spacerHeight)
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                    if outputPower > 0 {
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(
                            icon: "iphone",
                            value: nil,
                            isLeftSide: false
                        )
                    }
                } else {
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                    if outputPower > 0 {
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(
                            icon: hasTwoOutputs ? twoOutputIcons.first : "iphone",
                            value: nil,
                            isLeftSide: false
                        )
                        if hasTwoOutputs {
                            Spacer(minLength: Layout.spacerHeight)
                            NodeView(
                                icon: twoOutputIcons.second,
                                value: nil,
                                isLeftSide: false
                            )
                        }
                    }
                }
            case .both:
                NodeView(
                    icon: "laptopcomputer",
                    value: systemPower,
                    isLeftSide: false
                )
                .frame(height: Layout.largeNodeHeight)
            case .battery:
                NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
                if hasAnyOutput {
                    Spacer(minLength: Layout.spacerHeight)
                    if hasTwoOutputs {
                        NodeView(icon: "iphone", value: nil, isLeftSide: false)
                        Spacer(minLength: Layout.spacerHeight)
                        NodeView(icon: "display", value: nil, isLeftSide: false)
                    } else {
                        NodeView(icon: "iphone", value: nil, isLeftSide: false)
                    }
                }
            }
        }
    }

    private func drawMergeSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: smallHeight),
            topRight: CGPoint(
                x: rightX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomRight: CGPoint(x: rightX, y: size.height / 2)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height - smallHeight),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: size.height / 2),
            bottomRight: CGPoint(
                x: rightX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            )
        )
    }

    private func drawSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(
                x: leftX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomLeft: CGPoint(x: leftX, y: size.height / 2),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: smallHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height / 2),
            bottomLeft: CGPoint(
                x: leftX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            ),
            topRight: CGPoint(x: rightX, y: size.height - smallHeight),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawTripleSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        let totalGap = Layout.spacerHeight * 2
        let segmentHeight = (size.height - totalGap) / 3
        let midY = size.height / 2
        let leftTop = midY - Layout.largeNodeHeight / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop),
            bottomLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight / 3),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: segmentHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight / 3),
            bottomLeft: CGPoint(x: leftX, y: leftTop + (2 * Layout.largeNodeHeight / 3)),
            topRight: CGPoint(x: rightX, y: segmentHeight + Layout.spacerHeight),
            bottomRight: CGPoint(x: rightX, y: (2 * segmentHeight) + Layout.spacerHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: leftTop + (2 * Layout.largeNodeHeight / 3)),
            bottomLeft: CGPoint(x: leftX, y: leftTop + Layout.largeNodeHeight),
            topRight: CGPoint(x: rightX, y: (2 * segmentHeight) + (2 * Layout.spacerHeight)),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawSimpleFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    /// Draws a unified curved "tube" between four specific corners
    private func drawTube(
        context: GraphicsContext,
        topLeft: CGPoint,
        bottomLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint
    ) {
        let controlX = topLeft.x + (topRight.x - topLeft.x) * 0.5

        let path = Path { p in
            p.move(to: topLeft)
            p.addCurve(
                to: topRight,
                control1: CGPoint(x: controlX, y: topLeft.y),
                control2: CGPoint(x: controlX, y: topRight.y)
            )
            p.addLine(to: bottomRight)
            p.addCurve(
                to: bottomLeft,
                control1: CGPoint(x: controlX, y: bottomRight.y),
                control2: CGPoint(x: controlX, y: bottomLeft.y)
            )
            p.closeSubpath()
        }

        context.fill(
            path,
            with: .color(Color.primary.opacity(Layout.flowOpacity))
        )
    }
}

struct PowerLabel: View {
    let power: Double
    var body: some View {
        Text(String(format: "%.0f W", abs(power)))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

struct NodeView: View {
    let icon: String
    let value: Double?
    let isLeftSide: Bool
    let cornerRadius: CGFloat = 16.0

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                style: .continuous
            )
            .fill(Color.primary.opacity(0.05))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 60)

            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                if let value {
                    Text(String(format: "%.0f W", value))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NodeView(icon: "battery.100.bolt", value: 36.5, isLeftSide: true).frame(
        height: 100
    )
}

#Preview {
    let items: [(PowerSource, Bool, Double, Double, Double, Double, [Double])] = [
        (.both, false, -20.16, 36.0, 56.16, 0, []),
        (.acAdapter, true, 20.0, 30.0, 7.0, 3.0, [3.0]),
        (.battery, false, -18.63, 0.0, 18.63, 0, []),
        (.acAdapter, false, 0.0, 25.0, 11.0, 14.0, [9.0, 5.0]),
        (.acAdapter, false, 23, 39, 16, 0, []),
    ]
    LazyVGrid(
        columns: [
            GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
        ],
        spacing: 16
    ) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            PowerSankeyView(
                powerSource: item.0,
                isCharging: item.1,
                batteryPower: item.2,
                adapterPower: item.3,
                systemPower: item.4,
                outputPower: item.5,
                outputPortPowers: item.6
            )
            .frame(height: 125)
        }
    }
    .padding(12)
    .frame(width: 900)
}
