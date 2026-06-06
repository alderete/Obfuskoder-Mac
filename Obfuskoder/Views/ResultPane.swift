import SwiftUI
import AppKit
import ObfuskoderKit

struct ResultPane: View {
    @Bindable var model: AppModel
    @State private var showDecoded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(UIStrings.snippetHeading).font(.headline)
                Spacer()
                Text(UIStrings.updatesAsYouType).font(.caption).foregroundStyle(.tertiary)
            }

            snippetView

            HStack {
                Spacer()
                Button(copied ? UIStrings.copied : UIStrings.copy) { copy() }
                    .disabled(model.snippetText == nil)
                    .accessibilityLabel(UIStrings.copy)
            }

            Text(UIStrings.previewHeading).font(.headline)
            Group {
                if let html = model.snippetText {
                    PreviewWebView(html: html)
                } else {
                    placeholder
                }
            }
            .frame(minHeight: 120)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            if model.decodedSource != nil {
                DisclosureGroup(UIStrings.showDecodedSource, isExpanded: $showDecoded) {
                    Text(model.decodedSource ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var snippetView: some View {
        switch model.result {
        case .snippet(let s):
            ScrollView {
                Text(s.html)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 90)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
        case .failure:
            Text(UIStrings.encodeFailed).foregroundStyle(.red).frame(minHeight: 90, alignment: .topLeading)
        case .empty:
            placeholder.frame(minHeight: 90)
        }
    }

    private var placeholder: some View {
        Text(UIStrings.emptyResult)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy() {
        guard let html = model.snippetText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .string)
        copied = true
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: UIStrings.copied])
        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
    }
}
