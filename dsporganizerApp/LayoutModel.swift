//
//  LayoutModel.swift
//  DSPOrganizer
//
//  The edited screen layout and its synchronization with the system.
//

import AppKit
import Observation

typealias DisplayID = CGDirectDisplayID

struct ScreenItem: Identifiable, Equatable {
    let id: DisplayID
    let name: String
    let size: CGSize
    let isBuiltin: Bool
}

enum LayoutIssue: Equatable {
    case overlaps(DisplayID)
    case detached
}

@MainActor
@Observable
final class LayoutModel {
    private(set) var screens: [ScreenItem] = []

    /// Edited origins. Their frame is arbitrary: only positions relative to `mainID` matter.
    private(set) var origins: [DisplayID: CGPoint] = [:]
    private(set) var mainID: DisplayID = 0
    var selectedID: DisplayID?

    /// The layout as it is now, relative to the system main screen (which is always at {0,0}).
    private(set) var systemLayout: [DisplayID: CGPoint] = [:]
    private(set) var systemMainID: DisplayID = 0

    /// The current desktop picture of each screen, shown faintly on its tile.
    private(set) var wallpapers: [DisplayID: NSImage] = [:]
    /// Keyed by URL, so dragging (which reloads on every screen-parameters tick) doesn't redecode.
    @ObservationIgnored private var wallpaperCache: [URL: NSImage] = [:]

    /// Set after Apply when macOS placed screens differently from what was requested.
    private(set) var systemAdjustedLayout = false
    var errorMessage: String?

    /// Bumped when the layout changes as a whole (apply, undo, revert…): the map refits to it.
    private(set) var refitRequest = 0

    /// The window's undo manager; edits register their undo with it.
    @ObservationIgnored weak var undoManager: UndoManager?
    /// Nudges of one screen in quick succession undo as one step.
    @ObservationIgnored private var lastMove: (id: DisplayID, at: Date)?

    private var requestedLayout: [DisplayID: CGPoint]?
    /// Hides the "macOS adjusted the layout" warning after a while.
    @ObservationIgnored private var adjustedNoticeTask: Task<Void, Never>?
    private static let adjustedNoticeDuration: Duration = .seconds(10)
    /// Right after Apply macOS may still report the old layout for a moment; until it reports
    /// a new one (or a few seconds pass) whatever it reports is taken, not kept as edits.
    @ObservationIgnored private var settling: (layout: [DisplayID: CGPoint], mainID: DisplayID, until: Date)?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?

    init() {
        reload()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    // MARK: - Derived state

    var mainScreen: ScreenItem? { screens.first { $0.id == mainID } }

    /// For lists: the main screen first, then the others left to right.
    var listedScreens: [ScreenItem] {
        screens.filter { $0.id == mainID } + screens.filter { $0.id != mainID }
    }
    var selectedScreen: ScreenItem? { screens.first { $0.id == selectedID } }

    /// Edited layout relative to the edited main screen: what Apply will send.
    var layout: [DisplayID: CGPoint] {
        let base = origins[mainID] ?? .zero
        return origins.mapValues { CGPoint(x: $0.x - base.x, y: $0.y - base.y) }
    }

    var isDirty: Bool { mainID != systemMainID || layout != systemLayout }

    var command: String { positionCommand(main: mainID, positions: layout) }

    func relativeOrigin(of id: DisplayID) -> CGPoint { layout[id] ?? .zero }

    func rect(of screen: ScreenItem) -> CGRect {
        CGRect(origin: origins[screen.id] ?? .zero, size: screen.size)
    }

    var bounds: CGRect {
        screens.map(rect(of:)).reduce(CGRect.null) { $0.union($1) }
    }

    /// Problems macOS would "fix" on its own by moving screens around.
    var issues: [DisplayID: LayoutIssue] {
        var result: [DisplayID: LayoutIssue] = [:]
        let rects = Dictionary(uniqueKeysWithValues: screens.map { ($0.id, rect(of: $0)) })

        for a in screens {
            for b in screens where a.id != b.id {
                let overlap = rects[a.id]!.intersection(rects[b.id]!)
                if !overlap.isNull && overlap.width > 0 && overlap.height > 0 {
                    result[a.id] = .overlaps(b.id)
                }
            }
        }

        // every screen has to be reachable from the main one through shared edges
        var reached: Set<DisplayID> = [mainID]
        var queue = [mainID]
        while let current = queue.popLast() {
            for other in screens where !reached.contains(other.id) {
                if Self.touch(rects[current]!, rects[other.id]!) {
                    reached.insert(other.id)
                    queue.append(other.id)
                }
            }
        }
        for screen in screens where !reached.contains(screen.id) && result[screen.id] == nil {
            result[screen.id] = .detached
        }
        return result
    }

    /// `issues` and the outcome of the last Apply, as text.
    var warnings: [String] {
        let names = Dictionary(uniqueKeysWithValues: screens.map { ($0.id, $0.name) })
        var result = issues
            .sorted { $0.key < $1.key }
            .map { id, issue -> String in
                let name = names[id] ?? String(id)
                switch issue {
                case .overlaps(let other):
                    return "\(name) overlaps \(names[other] ?? String(other)): macOS will move it"
                case .detached:
                    return "\(name) does not touch the other screens: macOS will move it"
                }
            }
        if systemAdjustedLayout && !isDirty {
            result.append("macOS adjusted the requested layout, the map shows the actual one")
        }
        return result
    }

    private static func touch(_ a: CGRect, _ b: CGRect) -> Bool {
        let shareX = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        let shareY = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        // a shared edge of positive length, or an overlap
        return (shareX >= 0 && shareY > 0) || (shareY >= 0 && shareX > 0)
    }

    // MARK: - Editing

    /// Call once when a drag starts; the following `move`s undo as one step.
    func beginMove(_ id: DisplayID) {
        registerUndo("Move Screen")
        lastMove = nil
    }

    /// Moves without registering an undo: for dragging, after `beginMove`.
    func move(_ id: DisplayID, to origin: CGPoint) {
        origins[id] = CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
    }

    func nudge(_ id: DisplayID, dx: CGFloat, dy: CGFloat) {
        guard let origin = origins[id] else { return }
        registerMoveUndo(id)
        move(id, to: CGPoint(x: origin.x + dx, y: origin.y + dy))
    }

    /// Sets a position relative to the main screen. The main screen itself always stays at {0,0}.
    func setRelativeOrigin(of id: DisplayID, to point: CGPoint) {
        guard id != mainID, let base = origins[mainID] else { return }
        let origin = CGPoint(x: base.x + point.x, y: base.y + point.y)
        guard origins[id] != origin else { return }
        registerMoveUndo(id)
        move(id, to: origin)
    }

    func makeMain(_ id: DisplayID) {
        guard origins[id] != nil, id != mainID else { return }
        registerUndo("Make Main Screen")
        mainID = id
    }

    func revert() {
        guard isDirty else { return }
        registerUndo("Revert")
        resetToSystem()
        refitRequest += 1
    }

    private func resetToSystem() {
        origins = systemLayout
        mainID = systemMainID
    }

    // MARK: - Undo

    private struct Snapshot {
        let origins: [DisplayID: CGPoint]
        let mainID: DisplayID
    }

    private func registerMoveUndo(_ id: DisplayID) {
        let now = Date()
        if let lastMove, lastMove.id == id, now.timeIntervalSince(lastMove.at) < 1 {
            self.lastMove = (id, now)
            return
        }
        registerUndo("Move Screen")
        lastMove = (id, now)
    }

    private func registerUndo(_ name: String) {
        guard let undoManager else { return }
        let snapshot = Snapshot(origins: origins, mainID: mainID)
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.restore(snapshot, name: name) }
        }
        undoManager.setActionName(name)
        lastMove = nil
    }

    /// Undo and redo: each restore registers the opposite one.
    private func restore(_ snapshot: Snapshot, name: String) {
        registerUndo(name)
        origins = snapshot.origins.filter { screens.map(\.id).contains($0.key) }
        mainID = snapshot.mainID
        refitRequest += 1
    }

    // MARK: - System

    func reload(discardEdits: Bool = false) {
        let displays: [DisplayInfo]
        do {
            displays = try currentDisplays()
        } catch {
            errorMessage = String(describing: error)
            return
        }

        let isSettling = settling.map { Date() < $0.until } ?? false
        let keepEdits = !discardEdits && !isSettling && isDirty
        let sameScreens = Set(displays.map(\.id)) == Set(screens.map(\.id))

        screens = displays
            .sorted { $0.bounds.minX == $1.bounds.minX ? $0.id < $1.id : $0.bounds.minX < $1.bounds.minX }
            .map { ScreenItem(id: $0.id, name: $0.name, size: $0.bounds.size, isBuiltin: $0.isBuiltin) }
        systemMainID = (displays.first(where: \.isMain) ?? displays.first)?.id ?? 0
        systemLayout = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.bounds.origin) })
        reloadWallpapers(for: displays)

        // keep unsaved edits unless the set of screens has changed under them
        if !keepEdits || !sameScreens {
            resetToSystem()
        }
        if let settling {
            if systemLayout != settling.layout || systemMainID != settling.mainID || !isSettling {
                self.settling = nil
            }
            if isSettling && !discardEdits {
                refitRequest += 1  // the layout macOS settled on
            }
        }
        if !sameScreens {
            // the history refers to screens that are no longer (all) there
            undoManager?.removeAllActions(withTarget: self)
            refitRequest += 1
        }
        if let selectedID, origins[selectedID] == nil {
            self.selectedID = nil
        }
        if let requestedLayout {
            let adjusted = requestedLayout != systemLayout
            if adjusted && !systemAdjustedLayout {
                adjustedNoticeTask?.cancel()
                adjustedNoticeTask = Task { [weak self] in
                    try? await Task.sleep(for: Self.adjustedNoticeDuration)
                    guard !Task.isCancelled, let self else { return }
                    self.systemAdjustedLayout = false
                    self.requestedLayout = nil
                }
            }
            systemAdjustedLayout = adjusted
        }
    }

    private func reloadWallpapers(for displays: [DisplayInfo]) {
        var result: [DisplayID: NSImage] = [:]
        for display in displays {
            guard let screen = nsScreen(for: display.id),
                  let url = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }
            if let cached = wallpaperCache[url] {
                result[display.id] = cached
            } else if let image = NSImage(contentsOf: url) {
                wallpaperCache[url] = image
                result[display.id] = image
            }
        }
        wallpapers = result
    }

    /// Re-reads the system layout and drops all unsaved edits.
    func reset() {
        requestedLayout = nil
        systemAdjustedLayout = false
        reload(discardEdits: true)
        refitRequest += 1
    }

    func apply() {
        let requested = layout
        do {
            try applyDisplayLayout(main: mainID, positions: requested)
        } catch {
            errorMessage = String(describing: error)
            return
        }
        requestedLayout = requested
        settling = (systemLayout, systemMainID, Date().addingTimeInterval(3))
        // the edits are applied now: take whatever the system reports
        reload(discardEdits: true)
        refitRequest += 1
    }

    // MARK: - Presets

    func makePreset(named name: String) -> LayoutPreset {
        LayoutPreset(
            name: name,
            main: mainID,
            entries: layout.keys.sorted().map { id in
                let origin = layout[id]!
                return LayoutPreset.Entry(id: id, x: Int(origin.x), y: Int(origin.y))
            }
        )
    }

    /// Why `preset` cannot be used with the screens connected now, or nil if it can.
    func problem(with preset: LayoutPreset) -> String? {
        let known = Set(preset.entries.map(\.id))
        if !screens.contains(where: { $0.id == preset.main }) {
            return "Main screen \(preset.main) is not connected"
        }
        let unknown = screens.filter { !known.contains($0.id) }
        if !unknown.isEmpty {
            return "No position for " + unknown.map { "\($0.name) (\($0.id))" }.joined(separator: ", ")
        }
        return nil
    }

    func load(_ preset: LayoutPreset) {
        guard problem(with: preset) == nil else { return }
        registerUndo("Load Preset")
        for entry in preset.entries where origins[entry.id] != nil {
            origins[entry.id] = CGPoint(x: entry.x, y: entry.y)
        }
        mainID = preset.main
        refitRequest += 1
    }
}
