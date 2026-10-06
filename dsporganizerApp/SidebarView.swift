//
//  SidebarView.swift
//  DSPOrganizer
//
//  Connected screens and saved presets.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var model: LayoutModel
    var presets: PresetStore

    @State private var isNaming = false
    @State private var presetName = ""
    @State private var renaming: LayoutPreset?

    var body: some View {
        List(selection: $model.selectedID) {
            Section("Screens") {
                ForEach(model.listedScreens) { screen in
                    Label {
                        VStack(alignment: .leading) {
                            Text(screen.name)
                            Text(verbatim: "\(screen.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: screen.isBuiltin ? "laptopcomputer" : "display")
                    }
                    .badge(screen.id == model.mainID ? Text("main") : nil)
                    .tag(screen.id)
                }
            }

            Section("Presets") {
                ForEach(presets.presets) { preset in
                    PresetRow(preset: preset, problem: model.problem(with: preset))
                        .contextMenu {
                            Button("Load") { model.load(preset) }
                            Button("Load and Apply") {
                                model.load(preset)
                                model.apply()
                            }
                            Divider()
                            Button("Rename…") {
                                presetName = preset.name
                                renaming = preset
                            }
                            Button("Delete", role: .destructive) { presets.delete(preset) }
                        }
                        .onTapGesture(count: 2) { model.load(preset) }
                }
                if presets.presets.isEmpty {
                    Text("No presets yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save Layout as Preset…", systemImage: "plus") {
                presetName = ""
                isNaming = true
            }
            .buttonStyle(.borderless)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Save Layout as Preset", isPresented: $isNaming) {
            TextField("Name", text: $presetName)
            Button("Save") {
                presets.add(model.makePreset(named: trimmedName))
            }
            .disabled(trimmedName.isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Rename Preset",
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
            presenting: renaming
        ) { preset in
            TextField("Name", text: $presetName)
            Button("Rename") { presets.rename(preset, to: trimmedName) }
                .disabled(trimmedName.isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var trimmedName: String {
        presetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PresetRow: View {
    let preset: LayoutPreset
    let problem: String?

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(preset.name)
                Text(problem ?? "\(preset.entries.count) screens · double-click to load")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: problem == nil ? "rectangle.3.group" : "exclamationmark.triangle")
        }
        .opacity(problem == nil ? 1 : 0.6)
        .help(problem ?? preset.name)
    }
}
