//
//  PresetStore.swift
//  DSPOrganizer
//
//  Named layouts, kept in the user defaults.
//

import Foundation
import Observation

struct LayoutPreset: Codable, Identifiable, Hashable {
    struct Entry: Codable, Hashable {
        var id: DisplayID
        var x: Int
        var y: Int
    }

    var id = UUID()
    var name: String
    var main: DisplayID
    /// Positions relative to `main`, the main screen included (at {0,0}).
    var entries: [Entry]
}

@MainActor
@Observable
final class PresetStore {
    private static let defaultsKey = "presets"

    private(set) var presets: [LayoutPreset] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([LayoutPreset].self, from: data) {
            presets = stored
        }
    }

    func add(_ preset: LayoutPreset) {
        presets.append(preset)
        save()
    }

    func rename(_ preset: LayoutPreset, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        save()
    }

    func delete(_ preset: LayoutPreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
