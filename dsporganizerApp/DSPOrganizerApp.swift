//
//  DSPOrganizerApp.swift
//  DSPOrganizer
//
//  GUI for dsporganizer: position external screens with an accuracy of one pixel.
//

import SwiftUI

@main
struct DSPOrganizerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model: LayoutModel
    @State private var presets = PresetStore()
    @State private var overlay: ScreenOverlay

    init() {
        let model = LayoutModel()
        _model = State(initialValue: model)
        _overlay = State(initialValue: ScreenOverlay(model: model))
    }

    var body: some Scene {
        Window("DSP Organizer", id: "main") {
            ContentView(model: model, presets: presets, overlay: overlay)
                .frame(minWidth: 760, minHeight: 420)
        }
        .defaultSize(width: 1080, height: 640)
        .commands {
            CommandGroup(after: .toolbar) {
                Toggle("Show Seam Rulers", isOn: Binding(get: { overlay.showsSeams }, set: { overlay.showsSeams = $0 }))
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Toggle("Show Grid", isOn: Binding(get: { overlay.showsGrid }, set: { overlay.showsGrid = $0 }))
                    .keyboardShortcut("g")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
