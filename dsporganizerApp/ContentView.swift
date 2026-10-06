//
//  ContentView.swift
//  DSPOrganizer
//

import SwiftUI

struct ContentView: View {
    @Bindable var model: LayoutModel
    var presets: PresetStore
    @Bindable var overlay: ScreenOverlay

    @State private var showsInspector = true
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model, presets: presets)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            VStack(spacing: 0) {
                ScreenMapView(model: model, overlay: overlay)
                StatusBar(model: model)
            }
            .inspector(isPresented: $showsInspector) {
                InspectorView(model: model)
                    .inspectorColumnWidth(min: 220, ideal: 250)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Reload", systemImage: "arrow.clockwise") { model.reset() }
                    .help("Re-read the screen layout from the system, dropping the edits")
                    .keyboardShortcut("r")
                Button("Revert", systemImage: "arrow.uturn.backward") { model.revert() }
                    .help("Drop the edits")
                    .disabled(!model.isDirty)
                Button("Apply", systemImage: "checkmark") { model.apply() }
                    .help("Position the screens as shown (⌘↩)")
                    .keyboardShortcut(.return)
                    .disabled(!model.isDirty)
                Toggle(isOn: $overlay.showsSeams) {
                    Label("Seam Rulers", systemImage: "ruler")
                }
                .help("Rulers facing each other across the screen edges, over the real screens (⇧⌘G): their ticks meet when the edited layout matches the monitors")
                Menu {
                    Toggle("Show Grid", isOn: $overlay.showsGrid)
                    Picker("Grid Step", selection: $overlay.gridStep) {
                        ForEach(ScreenOverlay.gridSteps, id: \.self) { step in
                            Text(verbatim: "\(step) pt").tag(step)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Grid", systemImage: overlay.showsGrid ? "grid.circle.fill" : "grid")
                } primaryAction: {
                    overlay.showsGrid.toggle()
                }
                .help("Grid over the real screens (⌘G): lines continue straight across the bezels when the edited layout matches the monitors")
                Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
            }
        }
        .onAppear { model.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in model.undoManager = manager }
        .alert(
            "Cannot position screens",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }),
            presenting: model.errorMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }
}

/// Layout warnings and the CLI call reproducing the edited layout.
private struct StatusBar: View {
    var model: LayoutModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            HStack {
                Text(verbatim: "$ " + model.command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.command, forType: .string)
                }
                .help("Copy the command line for this layout")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
