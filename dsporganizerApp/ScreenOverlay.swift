//
//  ScreenOverlay.swift
//  DSPOrganizer
//
//  Click-through drawings over every physical screen, in the coordinates of the *edited*
//  layout, to check it against how the monitors really stand:
//   - seam rulers: a pair of rulers facing each other across every shared edge; with the
//     right layout their ticks and labels meet, otherwise the offset is read off directly;
//   - grid: lines over the whole screen that continue straight across the bezels;
//   - a frame around the screen selected on the map, while the app is active.
//

import AppKit
import Observation

/// A part of an edge this screen shares with a neighbour.
struct Seam {
    enum Side { case left, right, top, bottom }

    let side: Side
    /// Extent along the edge, in layout coordinates (y for left/right, x for top/bottom).
    let start: CGFloat
    let end: CGFloat
    let neighbour: String
}

@MainActor
@Observable
final class ScreenOverlay {
    static let gridSteps = [10, 20, 50, 100]
    private static let gridStepKey = "gridStep"

    var showsSeams = false {
        didSet { refresh() }
    }
    var showsGrid = false {
        didSet { refresh() }
    }
    var gridStep: Int = UserDefaults.standard.object(forKey: ScreenOverlay.gridStepKey) as? Int ?? 50 {
        didSet {
            UserDefaults.standard.set(gridStep, forKey: Self.gridStepKey)
            refresh()
        }
    }

    var isVisible: Bool { showsSeams || showsGrid }

    private var isAppActive = NSApplication.shared.isActive {
        didSet { refresh() }
    }

    @ObservationIgnored private let model: LayoutModel
    @ObservationIgnored private var windows: [DisplayID: NSWindow] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(model: LayoutModel) {
        self.model = model
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isAppActive = true }
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isAppActive = false }
            },
        ]
        trackModel()
    }

    /// Redraws on every edit of the layout, so the overlay follows dragging and nudging live.
    private func trackModel() {
        withObservationTracking {
            _ = model.layout
            _ = model.screens
            _ = model.selectedID
            _ = model.isDirty
        } onChange: { [weak self] in
            // called before the change lands: read the new values on the next turn
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.refresh()
                    self?.trackModel()
                }
            }
        }
    }

    private func refresh() {
        let highlighted = isAppActive ? model.selectedID : nil
        var seen: Set<DisplayID> = []
        let layout = model.layout
        let names = Dictionary(uniqueKeysWithValues: model.screens.map { ($0.id, $0.name) })
        let seams = showsSeams ? model.seams : [:]

        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let id = CGDirectDisplayID(truncating: number)
            guard isVisible || id == highlighted else { continue }
            seen.insert(id)

            let window = windows[id] ?? makeWindow()
            windows[id] = window
            window.setFrame(screen.frame, display: false)

            let view = window.contentView as! OverlayView
            view.origin = layout[id] ?? CGDisplayBounds(id).origin
            view.gridStep = showsGrid ? CGFloat(gridStep) : nil
            view.seams = seams[id] ?? []
            view.isHighlighted = id == highlighted
            view.isPreview = model.isDirty
            view.title = "\(names[id] ?? screen.localizedName)  ·  id \(id)"
            view.needsDisplay = true
            window.orderFrontRegardless()
        }

        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            windows[id] = nil
        }
        raiseAppWindows(isAppActive && !windows.isEmpty)
    }

    /// While the app is active its own windows stay above the overlay, so it never covers them;
    /// in the background they go back to normal and the overlay is above everything again.
    private func raiseAppWindows(_ raise: Bool) {
        let level = raise ? NSWindow.Level(rawValue: Self.level.rawValue + 1) : .normal
        for window in NSApplication.shared.windows where !(window is OverlayWindow) && window.canBecomeMain {
            window.level = level
        }
    }

    /// Above the menu bar (to draw over it), below pop-up menus (so those of the raised app window show).
    private static let level = NSWindow.Level.statusBar

    private func makeWindow() -> NSWindow {
        let window = OverlayWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = OverlayView()
        return window
    }
}

private final class OverlayWindow: NSWindow {}

extension LayoutModel {
    /// Shared edges of the edited layout, per screen.
    var seams: [DisplayID: [Seam]] {
        var result: [DisplayID: [Seam]] = [:]
        for a in screens {
            for b in screens where a.id != b.id {
                let ra = rect(of: a), rb = rect(of: b)
                // b to the right of a
                if ra.maxX == rb.minX {
                    let start = max(ra.minY, rb.minY), end = min(ra.maxY, rb.maxY)
                    if end > start {
                        result[a.id, default: []].append(Seam(side: .right, start: start, end: end, neighbour: b.name))
                        result[b.id, default: []].append(Seam(side: .left, start: start, end: end, neighbour: a.name))
                    }
                }
                // b below a
                if ra.maxY == rb.minY {
                    let start = max(ra.minX, rb.minX), end = min(ra.maxX, rb.maxX)
                    if end > start {
                        result[a.id, default: []].append(Seam(side: .bottom, start: start, end: end, neighbour: b.name))
                        result[b.id, default: []].append(Seam(side: .top, start: start, end: end, neighbour: a.name))
                    }
                }
            }
        }
        // positions are relative to the main screen, as everywhere in the UI
        let base = origins[mainID] ?? .zero
        return result.mapValues { seams in
            seams.map { seam in
                let shift = (seam.side == .left || seam.side == .right) ? base.y : base.x
                return Seam(side: seam.side, start: seam.start - shift, end: seam.end - shift, neighbour: seam.neighbour)
            }
        }
    }
}

/// Draws in layout coordinates; `origin` is where the top-left corner of this screen is in the edited layout.
private final class OverlayView: NSView {
    var origin: CGPoint = .zero
    var gridStep: CGFloat?
    var seams: [Seam] = []
    var isHighlighted = false
    /// The edited layout differs from the applied one.
    var isPreview = false
    var title = ""

    private static let rulerWidth: CGFloat = 64

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if isHighlighted {
            // the screen selected on the map; first, so rulers and grid stay on top
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(6)
            context.stroke(bounds.insetBy(dx: 3, dy: 3))
        }
        if let gridStep {
            drawGrid(context, step: gridStep)
        }
        for seam in seams {
            drawRuler(context, seam)
        }
        if gridStep != nil {
            let caption = "\(title)  ·  origin \(Int(origin.x)), \(Int(origin.y))"
            label(caption, at: CGPoint(x: bounds.midX, y: bounds.midY), size: 18, anchor: .center)
        }
    }

    // MARK: Seam rulers

    /// A ruler along the shared edge, ticks growing from the edge inwards:
    /// 1pt short, 5pt medium, 10pt long, 50pt long and labelled.
    private func drawRuler(_ context: CGContext, _ seam: Seam) {
        let vertical = seam.side == .left || seam.side == .right
        let base = vertical ? origin.y : origin.x
        let length = vertical ? bounds.height : bounds.width
        let from = max(seam.start - base, 0), to = min(seam.end - base, length)
        guard to > from else { return }
        let width = Self.rulerWidth

        // background band, so the ruler reads on any wallpaper
        let band: CGRect
        switch seam.side {
        case .left: band = CGRect(x: 0, y: from, width: width, height: to - from)
        case .right: band = CGRect(x: bounds.width - width, y: from, width: width, height: to - from)
        case .top: band = CGRect(x: from, y: 0, width: to - from, height: width)
        case .bottom: band = CGRect(x: from, y: bounds.height - width, width: to - from, height: width)
        }
        context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(band)

        var value = (seam.start).rounded(.up)
        while value <= seam.end {
            let at = value - base
            let n = Int(value)
            let tick: CGFloat
            let color: NSColor
            if n % 50 == 0 { tick = width * 0.55; color = .systemYellow }
            else if n % 10 == 0 { tick = width * 0.45; color = .white }
            else if n % 5 == 0 { tick = width * 0.3; color = .white }
            else { tick = width * 0.15; color = NSColor.white.withAlphaComponent(0.8) }

            // +0.5: a 1pt line exactly on a pixel row instead of blurred across two
            let p = at + 0.5
            let (a, b): (CGPoint, CGPoint)
            switch seam.side {
            case .left: (a, b) = (CGPoint(x: 0, y: p), CGPoint(x: tick, y: p))
            case .right: (a, b) = (CGPoint(x: bounds.width, y: p), CGPoint(x: bounds.width - tick, y: p))
            case .top: (a, b) = (CGPoint(x: p, y: 0), CGPoint(x: p, y: tick))
            case .bottom: (a, b) = (CGPoint(x: p, y: bounds.height), CGPoint(x: p, y: bounds.height - tick))
            }
            line(context, from: a, to: b, color: color.cgColor)

            if n % 50 == 0 && at > 6 && at < length - 6 {
                let text = String(n)
                switch seam.side {
                case .left: label(text, at: CGPoint(x: tick + 2, y: at), anchor: .leading)
                case .right: label(text, at: CGPoint(x: bounds.width - tick - 2, y: at), anchor: .trailing)
                case .top: label(text, at: CGPoint(x: at, y: tick + 2), anchor: .top)
                case .bottom: label(text, at: CGPoint(x: at, y: bounds.height - tick - 2), anchor: .bottom)
                }
            }
            value += 1
        }

        // which neighbour this ruler is to be compared with: the arrow points to it,
        // between the ruler and the name
        let mid = (from + to) / 2
        let lineHeight = NSAttributedString(string: "0", attributes: [.font: Self.labelFont(10)]).size().height
        switch seam.side {
        case .left:
            label("← \(seam.neighbour)", at: CGPoint(x: width + 4, y: mid), anchor: .leading)
        case .right:
            label("\(seam.neighbour) →", at: CGPoint(x: bounds.width - width - 4, y: mid), anchor: .trailing)
        case .top:
            label("↑", at: CGPoint(x: mid, y: width + 4), anchor: .top)
            label(seam.neighbour, at: CGPoint(x: mid, y: width + 4 + lineHeight), anchor: .top)
        case .bottom:
            label("↓", at: CGPoint(x: mid, y: bounds.height - width - 4), anchor: .bottom)
            label(seam.neighbour, at: CGPoint(x: mid, y: bounds.height - width - 4 - lineHeight), anchor: .bottom)
        }

        // the rulers follow the edited layout: say so while it differs from the applied one
        if isPreview {
            let orange = NSColor.systemOrange.withAlphaComponent(0.9)
            switch seam.side {
            case .left:
                label("preview", at: CGPoint(x: width + 4, y: mid + lineHeight + 2), background: orange, anchor: .leading)
            case .right:
                label("preview", at: CGPoint(x: bounds.width - width - 4, y: mid + lineHeight + 2), background: orange, anchor: .trailing)
            case .top:
                label("preview", at: CGPoint(x: mid, y: width + 4 + 2 * lineHeight + 2), background: orange, anchor: .top)
            case .bottom:
                label("preview", at: CGPoint(x: mid, y: bounds.height - width - 4 - 2 * lineHeight - 2), background: orange, anchor: .bottom)
            }
        }
    }

    // MARK: Grid

    private func drawGrid(_ context: CGContext, step: CGFloat) {
        guard step > 0 else { return }
        let minor = NSColor.systemRed.withAlphaComponent(0.35).cgColor
        let major = NSColor.systemRed.withAlphaComponent(0.85).cgColor
        let majorEvery = 5

        var x = (origin.x / step).rounded(.up) * step
        while x <= origin.x + bounds.width {
            let isMajor = Int((x / step).rounded()) % majorEvery == 0
            let lx = x - origin.x + 0.5
            line(context, from: CGPoint(x: lx, y: 0), to: CGPoint(x: lx, y: bounds.height), color: isMajor ? major : minor)
            if isMajor {
                // on both edges: the labels at the bezel are the ones compared with the neighbour
                label("x \(Int(x))", at: CGPoint(x: lx + 3, y: 30), anchor: .leading)
                label("x \(Int(x))", at: CGPoint(x: lx + 3, y: bounds.height - 30), anchor: .leading)
            }
            x += step
        }

        var y = (origin.y / step).rounded(.up) * step
        while y <= origin.y + bounds.height {
            let isMajor = Int((y / step).rounded()) % majorEvery == 0
            let ly = y - origin.y + 0.5
            line(context, from: CGPoint(x: 0, y: ly), to: CGPoint(x: bounds.width, y: ly), color: isMajor ? major : minor)
            if isMajor {
                label("y \(Int(y))", at: CGPoint(x: 4, y: ly + 8), anchor: .leading)
                label("y \(Int(y))", at: CGPoint(x: bounds.width - 4, y: ly + 8), anchor: .trailing)
            }
            y += step
        }

        // the screen edges, so a gap or an overlap at the bezel is visible too
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(2)
        context.stroke(bounds.insetBy(dx: 1, dy: 1))
    }

    // MARK: Primitives

    private func line(_ context: CGContext, from: CGPoint, to: CGPoint, color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }

    private enum Anchor { case center, leading, trailing, top, bottom }

    private static func labelFont(_ size: CGFloat) -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }

    /// `point` is the label's anchor; leading/trailing are vertically centred, top/bottom horizontally.
    private func label(_ text: String, at point: CGPoint, size: CGFloat = 10,
                       background: NSColor = NSColor.black.withAlphaComponent(0.6), anchor: Anchor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.labelFont(size),
            .foregroundColor: NSColor.white,
            .backgroundColor: background,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let s = string.size()
        let at: CGPoint
        switch anchor {
        case .center: at = CGPoint(x: point.x - s.width / 2, y: point.y - s.height / 2)
        case .leading: at = CGPoint(x: point.x, y: point.y - s.height / 2)
        case .trailing: at = CGPoint(x: point.x - s.width, y: point.y - s.height / 2)
        case .top: at = CGPoint(x: point.x - s.width / 2, y: point.y)
        case .bottom: at = CGPoint(x: point.x - s.width / 2, y: point.y - s.height)
        }
        string.draw(at: at)
    }
}
