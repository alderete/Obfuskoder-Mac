import SwiftUI
import ObfuskoderKit

struct ResultPane: View {
    @Bindable var model: AppModel
    @State private var showPreviewHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(UIStrings.snippetHeading).font(.headline)
                Spacer()
                Text(UIStrings.updatesAsYouType).font(.caption).foregroundStyle(.tertiary)
            }

            snippetView

            HStack(spacing: 8) {
                Spacer()
                if model.showCopiedFeedback {
                    Text(UIStrings.copied)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Button(UIStrings.copy) { model.copySnippet() }
                    .disabled(model.snippetText == nil)
            }
            .animation(.default, value: model.showCopiedFeedback)

            Text(UIStrings.previewHeading).font(.headline)
            Group {
                if let html = model.snippetText {
                    PreviewWebView(html: html,
                                   reloadKey: model.decodedSource ?? "",
                                   onInteractionAttempt: flashPreviewHint)
                } else {
                    placeholder
                }
            }
            .frame(minHeight: 120)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            if showPreviewHint {
                Label(UIStrings.previewNonInteractive, systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
            }

            if model.decodedSource != nil {
                DisclosureGroup(UIStrings.showDecodedSource, isExpanded: $model.showDecodedSource) {
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

    private func flashPreviewHint() {
        withAnimation { showPreviewHint = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { showPreviewHint = false }
        }
    }

}
