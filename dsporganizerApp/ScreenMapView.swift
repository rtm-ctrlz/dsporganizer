//
//  ScreenMapView.swift
//  DSPOrganizer
//
//  Scaled map of the screens: drag to move, arrows (keys or the buttons at the edges
//  of a screen) to nudge by 1px, with Shift by 10px. Edge snapping is optional.
//

import SwiftUI

/// Maps global screen coordinates to view coordinates.
private struct MapTransform {
    var scale: CGFloat
    var offset: CGPoint

    init(scale: CGFloat, offset: CGPoint) {
        self.scale = scale
        self.offset = offset
    }

    init(fitting bounds: CGRect, in size: CGSize, margin: CGFloat = 40) {
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else {
            scale = 1
            offset = .zero
            return
        }
        let available = CGSize(width: max(size.width - 2 * margin, 1), height: max(size.height - 2 * margin, 1))
        scale = min(available.width / bounds.width, available.height / bounds.height)
        offset = CGPoint(
            x: (size.width - bounds.width * scale) / 2 - bounds.minX * scale,
            y: (size.height - bounds.height * scale) / 2 - bounds.minY * scale
        )
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * scale + offset.x, y: rect.minY * scale + offset.y,
               width: rect.width * scale, height: rect.height * scale)
    }
}

struct ScreenMapView: View {
    @Bindable var model: LayoutModel
    var overlay: ScreenOverlay

    /// While a screen is selected its tile stays put on the map (scale and position):
    /// the rest of the map is drawn relative to it, so nudge buttons never run from the pointer.
    @State private var anchor: Anchor?
    /// While dragging the map does not change at all, so the dragged tile follows the pointer.
    @State private var frozenTransform: MapTransform?
    @State private var mapSize: CGSize = .zero
    @State private var dragStartOrigin: CGPoint?
    @State private var hoveredID: DisplayID?
    @AppStorage("snapScreens") private var snapsScreens = false
    @FocusState private var isFocused: Bool

    /// Snapping distance, in points of the map (not of the screens).
    private static let snapDistance: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let transform = currentTransform(in: geometry.size)
            let issues = model.issues

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectedID = nil }

                ForEach(model.screens) { screen in
                    let rect = transform.viewRect(model.rect(of: screen))
                    ScreenTile(
                        screen: screen,
                        origin: model.relativeOrigin(of: screen.id),
                        isMain: screen.id == model.mainID,
                        isSelected: screen.id == model.selectedID,
                        hasIssue: issues[screen.id] != nil,
                        showsControls: screen.id == model.selectedID || screen.id == hoveredID,
                        nudge: { dx, dy in
                            let step: CGFloat = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
                            select(screen.id)
                            model.nudge(screen.id, dx: dx * step, dy: dy * step)
                        }
                    )
                    .onHover { inside in
                        if inside { hoveredID = screen.id } else if hoveredID == screen.id { hoveredID = nil }
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .zIndex(screen.id == model.selectedID ? 1 : 0)
                    .onTapGesture { select(screen.id) }
                    .gesture(drag(screen, transform: transform))
                }

                if overlay.showsSeams {
                    // the seam rulers drawn over the real screens, at the map's scale
                    MapRulers(transform: transform, base: model.origins[model.mainID] ?? .zero,
                              rects: Dictionary(uniqueKeysWithValues: model.screens.map { ($0.id, model.rect(of: $0)) }),
                              seams: model.seams)
                        .allowsHitTesting(false)
                        .zIndex(3)
                }
                if overlay.showsGrid {
                    // the same grid as over the real screens, over the tiles
                    MapGrid(transform: transform, base: model.origins[model.mainID] ?? .zero,
                            step: CGFloat(overlay.gridStep))
                        .allowsHitTesting(false)
                        .zIndex(2)
                }
            }
            .coordinateSpace(name: "map")
            .onAppear { mapSize = geometry.size }
            .onChange(of: geometry.size) { _, size in
                mapSize = size
                // refit to the new size, then keep the selected screen where the refit put it
                anchor = nil
                anchor(model.selectedID, to: MapTransform(fitting: model.bounds, in: size))
            }
        }
        .onChange(of: model.refitRequest) {
            // the layout changed as a whole: fit it again, keeping the selected screen held
            withAnimation(.easeOut(duration: 0.2)) {
                anchor = nil
                anchor(model.selectedID, to: MapTransform(fitting: model.bounds, in: mapSize))
            }
        }
        .onChange(of: model.selectedID) { _, id in
            guard frozenTransform == nil else { return }  // a drag re-anchors when it ends
            if id == nil {
                withAnimation(.easeOut(duration: 0.2)) { anchor = nil }
            } else {
                // keep the map as it is now, just hold it by the newly selected screen
                anchor(id, to: currentTransform(in: mapSize))
            }
        }
        .overlay(alignment: .topLeading) {
            Toggle("Snap screens", isOn: $snapsScreens)
                .toggleStyle(.checkbox)
                .help("Snap the edges of a dragged screen to the edges of the others. Hold ⌥ while dragging to do the opposite.")
                .padding(10)
        }
        .background(.background.secondary)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            guard let id = model.selectedID else { return .ignored }
            let step: CGFloat = press.modifiers.contains(.shift) ? 10 : 1
            switch press.key {
            case .leftArrow: model.nudge(id, dx: -step, dy: 0)
            case .rightArrow: model.nudge(id, dx: step, dy: 0)
            case .upArrow: model.nudge(id, dx: 0, dy: -step)
            default: model.nudge(id, dx: 0, dy: step)
            }
            return .handled
        }
    }

    /// A screen held at a fixed point of the map, at a fixed scale.
    private struct Anchor {
        let id: DisplayID
        let viewOrigin: CGPoint
        let scale: CGFloat
    }

    private func currentTransform(in size: CGSize) -> MapTransform {
        if let frozenTransform {
            return frozenTransform
        }
        if let anchor, let screen = model.screens.first(where: { $0.id == anchor.id }) {
            let origin = model.rect(of: screen).origin
            return MapTransform(scale: anchor.scale, offset: CGPoint(
                x: anchor.viewOrigin.x - origin.x * anchor.scale,
                y: anchor.viewOrigin.y - origin.y * anchor.scale
            ))
        }
        return MapTransform(fitting: model.bounds, in: size)
    }

    /// Holds `id` where `transform` shows it.
    private func anchor(_ id: DisplayID?, to transform: MapTransform) {
        guard let id, let screen = model.screens.first(where: { $0.id == id }) else {
            anchor = nil
            return
        }
        anchor = Anchor(id: id, viewOrigin: transform.viewRect(model.rect(of: screen)).origin, scale: transform.scale)
    }

    private func select(_ id: DisplayID) {
        model.selectedID = id
        isFocused = true
    }

    private func drag(_ screen: ScreenItem, transform: MapTransform) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("map"))
            .onChanged { value in
                if dragStartOrigin == nil {
                    dragStartOrigin = model.rect(of: screen).origin
                    model.beginMove(screen.id)
                    frozenTransform = transform
                    select(screen.id)
                }
                guard let start = dragStartOrigin else { return }
                var origin = CGPoint(
                    x: start.x + value.translation.width / transform.scale,
                    y: start.y + value.translation.height / transform.scale
                )
                if snapsScreens != NSEvent.modifierFlags.contains(.option) {
                    origin = snapped(origin, of: screen, distance: Self.snapDistance / transform.scale)
                }
                model.move(screen.id, to: origin)
            }
            .onEnded { _ in
                dragStartOrigin = nil
                // hold the dragged screen where it was dropped: no jump when the drag ends
                if let frozenTransform {
                    anchor(screen.id, to: frozenTransform)
                }
                frozenTransform = nil
            }
    }
}

extension ScreenMapView {
    /// `origin` moved to the nearest edge of another screen, separately along each axis:
    /// edge to edge (side by side) or aligned (same left/right or top/bottom).
    fileprivate func snapped(_ origin: CGPoint, of screen: ScreenItem, distance: CGFloat) -> CGPoint {
        let others = model.screens.filter { $0.id != screen.id }.map(model.rect(of:))
        let size = screen.size

        func nearest(_ value: CGFloat, _ candidates: [CGFloat]) -> CGFloat {
            let best = candidates.min { abs($0 - value) < abs($1 - value) }
            if let best, abs(best - value) <= distance { return best }
            return value
        }
        return CGPoint(
            x: nearest(origin.x, others.flatMap { [$0.maxX, $0.minX - size.width, $0.minX, $0.maxX - size.width] }),
            y: nearest(origin.y, others.flatMap { [$0.maxY, $0.minY - size.height, $0.minY, $0.maxY - size.height] })
        )
    }
}

/// Grid lines at multiples of `step` in layout coordinates (relative to the main screen,
/// whose origin is `base` in the model's frame), every 5th one stronger.
private struct MapGrid: View {
    let transform: MapTransform
    let base: CGPoint
    let step: CGFloat

    /// Closer lines than this (in map points) would merge into a solid fill.
    private static let minSpacing: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            var step = step
            while step * transform.scale < Self.minSpacing {
                step *= 5
            }
            var minor = Path(), major = Path()

            // view → layout: (view - offset) / scale - base
            let fromX = (0 - transform.offset.x) / transform.scale - base.x
            let toX = (size.width - transform.offset.x) / transform.scale - base.x
            var x = (fromX / step).rounded(.up) * step
            while x <= toX {
                let vx = (x + base.x) * transform.scale + transform.offset.x
                let isMajor = Int((x / step).rounded()) % 5 == 0
                isMajor ? major.addLines([CGPoint(x: vx, y: 0), CGPoint(x: vx, y: size.height)])
                        : minor.addLines([CGPoint(x: vx, y: 0), CGPoint(x: vx, y: size.height)])
                x += step
            }

            let fromY = (0 - transform.offset.y) / transform.scale - base.y
            let toY = (size.height - transform.offset.y) / transform.scale - base.y
            var y = (fromY / step).rounded(.up) * step
            while y <= toY {
                let vy = (y + base.y) * transform.scale + transform.offset.y
                let isMajor = Int((y / step).rounded()) % 5 == 0
                isMajor ? major.addLines([CGPoint(x: 0, y: vy), CGPoint(x: size.width, y: vy)])
                        : minor.addLines([CGPoint(x: 0, y: vy), CGPoint(x: size.width, y: vy)])
                y += step
            }

            context.stroke(minor, with: .color(.red.opacity(0.25)), lineWidth: 0.5)
            context.stroke(major, with: .color(.red.opacity(0.6)), lineWidth: 1)
        }
    }
}

/// The seam rulers at the map's scale: ticks along every shared edge, growing inwards,
/// as dense as the scale allows, labelled in layout coordinates.
private struct MapRulers: View {
    let transform: MapTransform
    let base: CGPoint
    let rects: [DisplayID: CGRect]
    let seams: [DisplayID: [Seam]]

    private static let units: [CGFloat] = [1, 5, 10, 50, 100, 500, 1000]
    private static let band: CGFloat = 12

    var body: some View {
        Canvas { context, _ in
            let scale = transform.scale
            // smallest steps keeping ticks 4pt and labels 36pt apart on the map
            let tick = Self.units.first { $0 * scale >= 4 } ?? 1000
            let labelled = Self.units.first { $0 * scale >= 36 && $0 > tick } ?? 1000

            for (id, screenSeams) in seams {
                guard let rect = rects[id] else { continue }
                let view = transform.viewRect(rect)
                for seam in screenSeams {
                    draw(seam, on: view, tick: tick, labelled: labelled, in: &context)
                }
            }
        }
    }

    private func draw(_ seam: Seam, on view: CGRect, tick: CGFloat, labelled: CGFloat, in context: inout GraphicsContext) {
        let vertical = seam.side == .left || seam.side == .right
        // layout value along the edge → map coordinate
        func at(_ value: CGFloat) -> CGFloat {
            vertical ? (value + base.y) * transform.scale + transform.offset.y
                     : (value + base.x) * transform.scale + transform.offset.x
        }
        let from = at(seam.start), to = at(seam.end)
        let band = Self.band

        let bandRect: CGRect
        switch seam.side {
        case .left: bandRect = CGRect(x: view.minX, y: from, width: band, height: to - from)
        case .right: bandRect = CGRect(x: view.maxX - band, y: from, width: band, height: to - from)
        case .top: bandRect = CGRect(x: from, y: view.minY, width: to - from, height: band)
        case .bottom: bandRect = CGRect(x: from, y: view.maxY - band, width: to - from, height: band)
        }
        context.fill(Path(bandRect), with: .color(.black.opacity(0.6)))

        var ticks = Path(), long = Path()
        var value = (seam.start / tick).rounded(.up) * tick
        while value <= seam.end {
            let p = at(value)
            let isLabelled = Int(value.rounded()) % Int(labelled) == 0
            let length = isLabelled ? band : band * 0.5
            let (a, b): (CGPoint, CGPoint)
            switch seam.side {
            case .left: (a, b) = (CGPoint(x: view.minX, y: p), CGPoint(x: view.minX + length, y: p))
            case .right: (a, b) = (CGPoint(x: view.maxX, y: p), CGPoint(x: view.maxX - length, y: p))
            case .top: (a, b) = (CGPoint(x: p, y: view.minY), CGPoint(x: p, y: view.minY + length))
            case .bottom: (a, b) = (CGPoint(x: p, y: view.maxY), CGPoint(x: p, y: view.maxY - length))
            }
            if isLabelled {
                long.addLines([a, b])
                let text = Text(verbatim: String(Int(value.rounded())))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundColor(.primary)
                switch seam.side {
                case .left: context.draw(text, at: CGPoint(x: b.x + 2, y: p), anchor: .leading)
                case .right: context.draw(text, at: CGPoint(x: b.x - 2, y: p), anchor: .trailing)
                case .top: context.draw(text, at: CGPoint(x: p, y: b.y + 1), anchor: .top)
                case .bottom: context.draw(text, at: CGPoint(x: p, y: b.y - 1), anchor: .bottom)
                }
            } else {
                ticks.addLines([a, b])
            }
            value += tick
        }
        context.stroke(ticks, with: .color(.white.opacity(0.8)), lineWidth: 0.5)
        context.stroke(long, with: .color(.yellow), lineWidth: 1)
    }
}

private struct ScreenTile: View {
    let screen: ScreenItem
    let origin: CGPoint
    let isMain: Bool
    let isSelected: Bool
    let hasIssue: Bool
    let showsControls: Bool
    let nudge: (_ dx: CGFloat, _ dy: CGFloat) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack(alignment: .top) {
            shape.fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.3)) : AnyShapeStyle(.quaternary))

            if isMain {
                // the menu bar lives on the main screen
                Rectangle()
                    .fill(.secondary)
                    .frame(height: 5)
            }

            VStack(spacing: 2) {
                Text(screen.name)
                    .font(.headline)
                Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))")
                Text(verbatim: "\(Int(origin.x)), \(Int(origin.y))")
                    .monospacedDigit()
                Text(verbatim: "id \(screen.id)")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.4)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                hasIssue ? Color.red : (isSelected ? Color.accentColor : Color.secondary.opacity(0.5)),
                lineWidth: isSelected || hasIssue ? 2 : 1
            )
        }
        .contentShape(shape)
        .overlay {
            if showsControls {
                GeometryReader { geometry in
                    // too small a tile: the buttons would cover the labels
                    if geometry.size.width >= 90 && geometry.size.height >= 70 {
                        nudgeButtons
                    }
                }
            }
        }
    }

    private var nudgeButtons: some View {
        ZStack {
            NudgeButton(systemImage: "chevron.left", help: "left") { nudge(-1, 0) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            NudgeButton(systemImage: "chevron.right", help: "right") { nudge(1, 0) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            NudgeButton(systemImage: "chevron.up", help: "up") { nudge(0, -1) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            NudgeButton(systemImage: "chevron.down", help: "down") { nudge(0, 1) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(4)
    }
}

private struct NudgeButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 20, height: 20)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .help("Move \(help) by 1px, with Shift by 10px")
    }
}
