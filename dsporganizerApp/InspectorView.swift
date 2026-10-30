//
//  InspectorView.swift
//  DSPOrganizer
//
//  Exact position of the selected screen.
//

import SwiftUI

struct InspectorView: View {
    @Bindable var model: LayoutModel

    var body: some View {
        if let screen = model.selectedScreen {
            Form {
                Section(screen.name) {
                    LabeledContent("Id") { Text(verbatim: "\(screen.id)").textSelection(.enabled) }
                    LabeledContent("Size") {
                        Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))")
                    }
                }

                Section("Position") {
                    if screen.id == model.mainID {
                        Text("The main screen is always at 0, 0. Other screens are positioned relative to it.")
                            .foregroundStyle(.secondary)
                    } else {
                        // .id: fresh fields per screen, so half-typed text never lands on another screen
                        CoordinateField(label: "X", value: coordinate(screen.id, \.x))
                            .id("x-\(screen.id)")
                        CoordinateField(label: "Y", value: coordinate(screen.id, \.y))
                            .id("y-\(screen.id)")
                        Text("↑/↓ in a field change it by 1px, with Shift by 10px. On the map the arrow keys move the selected screen the same way.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Make Main Screen") { model.makeMain(screen.id) }
                        .disabled(screen.id == model.mainID)
                } footer: {
                    Text("The main screen carries the menu bar.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        } else {
            LayoutOverview(model: model)
        }
    }

    private func coordinate(_ id: DisplayID, _ axis: WritableKeyPath<CGPoint, CGFloat>) -> Binding<Int> {
        Binding(
            get: { Int(model.relativeOrigin(of: id)[keyPath: axis]) },
            set: { value in
                var origin = model.relativeOrigin(of: id)
                origin[keyPath: axis] = CGFloat(value)
                model.setRelativeOrigin(of: id, to: origin)
            }
        )
    }
}

private struct CoordinateField: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                IntegerField(value: $value)
                    .frame(width: 80)
                Stepper(label, value: $value)
                    .labelsHidden()
            }
        }
    }
}

/// An integer text field where ↑/↓ change the value by 1, with Shift by 10.
private struct IntegerField: NSViewRepresentable {
    @Binding var value: Int

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.delegate = context.coordinator
        field.stringValue = String(value)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.value = $value
        // the value can change elsewhere (map, arrows); don't clobber what is being typed
        if !context.coordinator.isTyping, field.stringValue != String(value) {
            field.stringValue = String(value)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var value: Binding<Int>
        var isTyping = false

        init(value: Binding<Int>) { self.value = value }

        func controlTextDidChange(_ notification: Notification) {
            isTyping = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            isTyping = false
            if let typed = Self.parse(field.stringValue) {
                value.wrappedValue = typed
            }
            field.stringValue = String(value.wrappedValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let step: Int
            switch selector {
            case #selector(NSResponder.moveUp(_:)): step = 1
            case #selector(NSResponder.moveDown(_:)): step = -1
            case #selector(NSResponder.moveUpAndModifySelection(_:)): step = 10
            case #selector(NSResponder.moveDownAndModifySelection(_:)): step = -10
            case #selector(NSResponder.insertNewline(_:)):
                isTyping = false
                if let typed = Self.parse(textView.string) {
                    value.wrappedValue = typed
                }
                textView.string = String(value.wrappedValue)
                textView.selectAll(nil)
                return true
            default:
                return false
            }
            // step from what is typed, so "1500" then ↑ gives 1501 even before Return
            let next = (Self.parse(textView.string) ?? value.wrappedValue) + step
            isTyping = false
            value.wrappedValue = next
            textView.string = String(next)
            textView.selectAll(nil)
            return true
        }

        private static func parse(_ text: String) -> Int? {
            Int(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\u{2212}", with: "-"))
        }
    }
}

/// What the inspector shows with no screen selected: the layout as a whole.
private struct LayoutOverview: View {
    var model: LayoutModel

    var body: some View {
        Form {
            Section("Layout") {
                LabeledContent("Main screen") { Text(model.mainScreen?.name ?? "—") }
                LabeledContent("State") {
                    if model.isDirty {
                        Label("Edited, not applied", systemImage: "pencil.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Applied", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                if model.isDirty {
                    HStack {
                        Spacer()
                        Button("Revert") { model.revert() }
                        Button("Apply") { model.apply() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section {
                ForEach(model.listedScreens) { screen in
                    Button {
                        model.selectedID = screen.id
                    } label: {
                        LabeledContent {
                            let origin = model.relativeOrigin(of: screen.id)
                            Text(verbatim: "\(Int(origin.x)), \(Int(origin.y))")
                                .monospacedDigit()
                        } label: {
                            Text(screen.name)
                            Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))  ·  id \(screen.id)"
                                 + (screen.id == model.mainID ? "  ·  main" : ""))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Screens")
            } footer: {
                Text("Positions are relative to the main screen. Click a screen to edit it.")
                    .foregroundStyle(.secondary)
            }

            if !model.warnings.isEmpty {
                Section("Warnings") {
                    ForEach(model.warnings) { warning in
                        WarningRow(model: model, warning: warning)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
