import SwiftUI

struct PowerSankeyView: View {
    let powerSource: PowerSource
    let isCharging: Bool
    let batteryPower: Double
    let adapterPower: Double
    let systemPower: Double

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
                switch powerSource {
                case .acAdapter:
                    if batteryPower > 0 {
                        Canvas { context, size in
                            drawSplitSankeyFlow(context: context, size: size)
                        }
                        VStack(spacing: Layout.powerLabelSpacing) {
                            Text(String(format: "%.0f W", abs(batteryPower)))
                                .font(
                                    .system(
                                        size: Layout.powerLabelSize,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f W", abs(systemPower)))
                                .font(
                                    .system(
                                        size: Layout.powerLabelSize,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Canvas { context, size in
                            drawSimpleFlow(
                                context: context,
                                from: CGPoint(
                                    x: Layout.nodeWidth + Layout.gap,
                                    y: size.height * 0.5
                                ),
                                to: CGPoint(
                                    x: size.width - Layout.nodeWidth
                                        - Layout.gap,
                                    y: size.height * 0.5
                                ),
                                height: size.height
                            )
                        }
                        Text(String(format: "%.0f W", abs(adapterPower)))
                            .font(
                                .system(
                                    size: Layout.powerLabelSize,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.secondary)
                    }

                case .both:
                    Canvas { context, size in
                        drawMergeSankeyFlow(context: context, size: size)
                    }
                    VStack(spacing: Layout.powerLabelSpacing) {
                        Text(String(format: "%.0f W", abs(batteryPower)))
                            .font(
                                .system(
                                    size: Layout.powerLabelSize,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f W", abs(adapterPower)))
                            .font(
                                .system(
                                    size: Layout.powerLabelSize,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.secondary)
                    }

                case .battery:
                    Canvas { context, size in
                        drawSimpleFlow(
                            context: context,
                            from: CGPoint(
                                x: Layout.nodeWidth + Layout.gap,
                                y: size.height * 0.5
                            ),
                            to: CGPoint(
                                x: size.width - Layout.nodeWidth - Layout.gap,
                                y: size.height * 0.5
                            ),
                            height: size.height
                        )
                    }
                    Text(String(format: "%.0f W", systemPower))
                        .font(
                            .system(
                                size: Layout.powerLabelSize,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(.secondary)
                }

                HStack {
                    VStack {
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
                                NodeView(
                                    icon: "powerplug.fill",
                                    value: nil,
                                    isLeftSide: true
                                )
                            }

                        case .both:
                            NodeView(
                                icon: "battery.100",
                                value: nil,
                                isLeftSide: true
                            )
                            Spacer(minLength: Layout.spacerHeight)
                            NodeView(
                                icon: "powerplug.fill",
                                value: nil,
                                isLeftSide: true
                            )

                        case .battery:
                            NodeView(
                                icon: "battery.100",
                                value: nil,
                                isLeftSide: true
                            )
                        }
                    }

                    Spacer()

                    VStack {
                        switch powerSource {
                        case .acAdapter:
                            if batteryPower > 0 {
                                if isCharging {
                                    NodeView(
                                        icon: "battery.100.bolt",
                                        value: nil,
                                        isLeftSide: false
                                    )
                                } else {
                                    NodeView(
                                        icon: "battery.100",
                                        value: nil,
                                        isLeftSide: false
                                    )
                                }
                                Spacer(minLength: Layout.spacerHeight)
                                NodeView(
                                    icon: "laptopcomputer",
                                    value: nil,
                                    isLeftSide: false
                                )
                            } else {
                                NodeView(
                                    icon: "laptopcomputer",
                                    value: abs(systemPower),
                                    isLeftSide: false
                                )
                            }

                        case .both:
                            NodeView(
                                icon: "laptopcomputer",
                                value: systemPower,
                                isLeftSide: false
                            )
                            .frame(height: Layout.largeNodeHeight)

                        case .battery:
                            NodeView(
                                icon: "laptopcomputer",
                                value: nil,
                                isLeftSide: false
                            )
                        }
                    }
                }
            }
        }
        .frame(height: Layout.viewHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func drawMergeSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        let smallNodeHeight = (size.height - Layout.spacerHeight) / 2

        let batteryY = smallNodeHeight / 2
        let adapterY = size.height - smallNodeHeight / 2

        let systemY = size.height / 2

        let systemTop = systemY - Layout.largeNodeHeight / 2
        let systemMid = systemY
        let systemBottom = systemY + Layout.largeNodeHeight / 2

        drawFlowPath(
            context: context,
            fromX: leftX,
            fromY: batteryY,
            toX: rightX,
            toYTop: systemTop,
            toYBottom: systemMid,
            sourceHeight: smallNodeHeight
        )

        drawFlowPath(
            context: context,
            fromX: leftX,
            fromY: adapterY,
            toX: rightX,
            toYTop: systemMid,
            toYBottom: systemBottom,
            sourceHeight: smallNodeHeight
        )
    }

    private func drawSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        let smallNodeHeight = (size.height - Layout.spacerHeight) / 2

        let adapterY = size.height / 2

        let batteryY = smallNodeHeight / 2
        let systemY = size.height - smallNodeHeight / 2

        let adapterTop = adapterY - Layout.largeNodeHeight / 2
        let adapterMid = adapterY
        let adapterBottom = adapterY + Layout.largeNodeHeight / 2

        drawSplitFlowPath(
            context: context,
            fromX: leftX,
            fromYTop: adapterTop,
            fromYBottom: adapterMid,
            toX: rightX,
            toY: batteryY,
            destHeight: smallNodeHeight
        )

        drawSplitFlowPath(
            context: context,
            fromX: leftX,
            fromYTop: adapterMid,
            fromYBottom: adapterBottom,
            toX: rightX,
            toY: systemY,
            destHeight: smallNodeHeight
        )
    }

    private func drawFlowPath(
        context: GraphicsContext,
        fromX: CGFloat,
        fromY: CGFloat,
        toX: CGFloat,
        toYTop: CGFloat,
        toYBottom: CGFloat,
        sourceHeight: CGFloat
    ) {
        let path = Path { p in
            let halfHeight = sourceHeight / 2
            let controlX = fromX + (toX - fromX) * 0.5

            p.move(to: CGPoint(x: fromX, y: fromY - halfHeight))
            p.addCurve(
                to: CGPoint(x: toX, y: toYTop),
                control1: CGPoint(x: controlX, y: fromY - halfHeight),
                control2: CGPoint(x: controlX, y: toYTop)
            )

            p.addLine(to: CGPoint(x: toX, y: toYBottom))

            p.addCurve(
                to: CGPoint(x: fromX, y: fromY + halfHeight),
                control1: CGPoint(x: controlX, y: toYBottom),
                control2: CGPoint(x: controlX, y: fromY + halfHeight)
            )

            p.closeSubpath()
        }

        context.fill(
            path,
            with: .color(Color.primary.opacity(Layout.flowOpacity))
        )
    }

    private func drawSplitFlowPath(
        context: GraphicsContext,
        fromX: CGFloat,
        fromYTop: CGFloat,
        fromYBottom: CGFloat,
        toX: CGFloat,
        toY: CGFloat,
        destHeight: CGFloat
    ) {
        let path = Path { p in
            let halfHeight = destHeight / 2
            let controlX = fromX + (toX - fromX) * 0.5

            p.move(to: CGPoint(x: fromX, y: fromYTop))
            p.addCurve(
                to: CGPoint(x: toX, y: toY - halfHeight),
                control1: CGPoint(x: controlX, y: fromYTop),
                control2: CGPoint(x: controlX, y: toY - halfHeight)
            )

            p.addLine(to: CGPoint(x: toX, y: toY + halfHeight))

            p.addCurve(
                to: CGPoint(x: fromX, y: fromYBottom),
                control1: CGPoint(x: controlX, y: toY + halfHeight),
                control2: CGPoint(x: controlX, y: fromYBottom)
            )

            p.closeSubpath()
        }

        context.fill(
            path,
            with: .color(Color.primary.opacity(Layout.flowOpacity))
        )
    }

    private func drawSimpleFlow(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        height: CGFloat
    ) {
        let path = Path { p in
            let halfHeight = height / 2
            let controlX = from.x + (to.x - from.x) * 0.5

            p.move(to: CGPoint(x: from.x, y: from.y - halfHeight))
            p.addCurve(
                to: CGPoint(x: to.x, y: to.y - halfHeight),
                control1: CGPoint(x: controlX, y: from.y - halfHeight),
                control2: CGPoint(x: controlX, y: to.y - halfHeight)
            )

            p.addLine(to: CGPoint(x: to.x, y: to.y + halfHeight))

            p.addCurve(
                to: CGPoint(x: from.x, y: from.y + halfHeight),
                control1: CGPoint(x: controlX, y: to.y + halfHeight),
                control2: CGPoint(x: controlX, y: from.y + halfHeight)
            )

            p.closeSubpath()
        }

        context.fill(
            path,
            with: .color(Color.primary.opacity(Layout.flowOpacity))
        )
    }
}

struct NodeView: View {
    let icon: String
    let value: Double?
    let isLeftSide: Bool

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeftSide ? 20 : 0,
                bottomLeadingRadius: isLeftSide ? 20 : 0,
                bottomTrailingRadius: isLeftSide ? 0 : 20,
                topTrailingRadius: isLeftSide ? 0 : 20
            )
            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            .frame(width: 60)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: isLeftSide ? 20 : 0,
                    bottomLeadingRadius: isLeftSide ? 20 : 0,
                    bottomTrailingRadius: isLeftSide ? 0 : 20,
                    topTrailingRadius: isLeftSide ? 0 : 20
                )
                .fill(Color.primary.opacity(0.05))
            )

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
    VStack(spacing: 30) {
        PowerSankeyView(
            powerSource: .both,
            isCharging: false,
            batteryPower: -20.16,
            adapterPower: 36.0,
            systemPower: 56.16
        ).frame(height: 125)

        PowerSankeyView(
            powerSource: .acAdapter,
            isCharging: true,
            batteryPower: 20.0,
            adapterPower: 30.0,
            systemPower: 10.0
        ).frame(height: 125)

        PowerSankeyView(
            powerSource: .battery,
            isCharging: false,
            batteryPower: -18.63,
            adapterPower: 0.0,
            systemPower: 18.63
        ).frame(height: 125)

        PowerSankeyView(
            powerSource: .acAdapter,
            isCharging: false,
            batteryPower: 0.0,
            adapterPower: 25.0,
            systemPower: 25.0
        ).frame(height: 125)

        PowerSankeyView(
            powerSource: .acAdapter,
            isCharging: false,
            batteryPower: 23,
            adapterPower: 39,
            systemPower: 16
        ).frame(height: 125)
    }
    .padding(.vertical, 12)
    .frame(width: 300)
}
