//
//  displays.swift
//  dsporganizer
//
//  Display enumeration and positioning shared by the CLI and the GUI app.
//

import Foundation
import AppKit
import CoreGraphics

struct DisplayInfo {
    let id: CGDirectDisplayID
    // CGDisplayBounds: global Quartz coordinates, {0,0} is the top-left of the main screen
    let bounds: CGRect
    let isMain: Bool
    let isBuiltin: Bool
    let name: String
}

enum DisplayError: Error, CustomStringConvertible {
    case cannotListDisplays(CGError)
    case singleDisplay
    case undefinedDisplay(CGDirectDisplayID)
    case missingMain(CGDirectDisplayID)
    case nothingToPosition
    case configuration(CGError)

    var description: String {
        switch self {
        case .cannotListDisplays(let err):
            return "cannot get displays: \(err.rawValue)"
        case .singleDisplay:
            return "only one display found!"
        case .undefinedDisplay(let id):
            return "found undefined screen (\(id))"
        case .missingMain(let id):
            return "missing main screen (\(id))"
        case .nothingToPosition:
            return "no screens to position"
        case .configuration(let err):
            return "display configuration failed: \(err.rawValue)"
        }
    }
}

func activeDisplayIDs() throws -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: MAX_DISPLAYS)
    var count: CGDisplayCount = 0
    let err = CGGetActiveDisplayList(UInt32(MAX_DISPLAYS), &ids, &count)
    if (err != CGError.success) {
        throw DisplayError.cannotListDisplays(err)
    }
    return Array(ids.prefix(Int(count)))
}

func currentDisplays() throws -> [DisplayInfo] {
    var names: [CGDirectDisplayID: String] = [:]
    for screen in NSScreen.screens {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            names[CGDirectDisplayID(truncating: number)] = screen.localizedName
        }
    }
    return try activeDisplayIDs().map({ id in
        return DisplayInfo(
            id: id,
            bounds: CGDisplayBounds(id),
            isMain: CGDisplayIsMain(id) != 0,
            isBuiltin: CGDisplayIsBuiltin(id) != 0,
            name: names[id] ?? "Display \(id)"
        )
    })
}

/// Moves `main` to {0,0} and every other screen to its origin in `positions`.
/// Every active screen must be either `main` or present in `positions`;
/// entries for screens that are not connected are skipped and returned.
@discardableResult
func applyDisplayLayout(main: CGDirectDisplayID,
                        positions: [CGDirectDisplayID: CGPoint],
                        option: CGConfigureOption = CGConfigureOption.forSession) throws -> [CGDirectDisplayID] {
    let active = try activeDisplayIDs()
    if (active.count == 1) {
        throw DisplayError.singleDisplay
    }

    var layout = positions
    layout[main] = CGPoint(x: 0, y: 0)
    for id in active where layout[id] == nil {
        throw DisplayError.undefinedDisplay(id)
    }
    let skipped = layout.keys.filter({ return !active.contains($0) }).sorted()
    for id in skipped {
        layout.removeValue(forKey: id)
    }
    if (layout[main] == nil) {
        throw DisplayError.missingMain(main)
    }
    if (layout.count == 1) {
        throw DisplayError.nothingToPosition
    }

    var config: CGDisplayConfigRef? = nil
    var err = CGBeginDisplayConfiguration(&config)
    if (err != CGError.success) {
        throw DisplayError.configuration(err)
    }
    for (id, origin) in layout {
        err = CGConfigureDisplayOrigin(config, id, Int32(origin.x), Int32(origin.y))
        if (err != CGError.success) {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configuration(err)
        }
    }
    err = CGCompleteDisplayConfiguration(config, option)
    if (err != CGError.success) {
        throw DisplayError.configuration(err)
    }
    return skipped
}

/// The CLI call reproducing a layout: one '-p' per screen, ordered by screen id,
/// so the line is stable between runs.
func positionCommand(main: CGDirectDisplayID, positions: [CGDirectDisplayID: CGPoint]) -> String {
    let posArgs = positions.keys
        .filter({ return $0 != main })
        .sorted()
        .map({ (id: CGDirectDisplayID) -> String in
            let origin = positions[id]!
            return "-p \(id):\(Int(origin.x))x\(Int(origin.y))"
        })
    return ([prog, "-m", String(main)] + posArgs).joined(separator: " ")
}
