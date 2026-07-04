import SwiftUI
import AppKit
import ObfuskoderKit

struct ResultPane: View {
    @Bindable var model: AppModel
    @State private var previewContentHeight: CGFloat?

    var body: some View {
        // The snippet is a chunky block of code; the preview is usually a
        // one-line link. Give the snippet block ~60% of the pane and let the
        // preview + decoded source share the rest (WIN-2).
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(UIStrings.snippetHeading).font(.appHeadline)
                        Spacer()
                        Text(UIStrings.updatesAsYouType).font(.caption).foregroundStyle(.tertiary)
                    }

                    snippetView

                    HStack(spacing: 8) {
                        Spacer()
                        if model.showCopiedFeedback {
                            Text(UIStrings.copied)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .transition(.opacity)
                        }
                        Button(UIStrings.copy, systemImage: "doc.on.doc") { model.copySnippet() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.snippetText == nil)
                            .phaseAnimator([1.0, 1.07], trigger: model.copyCount) { view, scale in
                                view.scaleEffect(scale)
                            } animation: { _ in .spring(duration: 0.18) }
                    }
                    .animation(.default, value: model.showCopiedFeedback)
                }
                .frame(height: geo.size.height * 0.6, alignment: .top)

                Text(UIStrings.previewHeading).font(.appHeadline)
                // While decoded source is open, the preview squeezes to its
                // rendered content's height (capped so a tall Advanced-mode
                // preview can't starve the decoded source) — WIN-3.
                let pinnedHeight = pinnedPreviewHeight(paneHeight: geo.size.height)
                Group {
                    if let html = model.snippetText {
                        PreviewWebView(html: html,
                                       reloadKey: model.decodedSource ?? "",
                                       onInteractionAttempt: announcePreviewIsNonInteractive,
                                       onContentHeight: { previewContentHeight = $0 })
                    } else {
                        emptyState(UIStrings.emptyPreview)
                    }
                }
                .frame(height: pinnedHeight)
                .frame(minHeight: pinnedHeight == nil ? 64 : nil)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

                if model.decodedSource != nil {
                    DisclosureGroup(UIStrings.showDecodedSource, isExpanded: $model.showDecodedSource) {
                        ScrollView {
                            Text(model.decodedSource ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .animation(.default, value: model.showDecodedSource)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // Same box geometry as the preview, but filled with textBackgroundColor —
    // the surface macOS uses for live, selectable text — while the preview
    // keeps a gray wash to read as display-only (WIN-4).
    @ViewBuilder private var snippetView: some View {
        Group {
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
            case .failure:
                Text(UIStrings.encodeFailed)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            case .empty:
                emptyState(UIStrings.emptySnippet).frame(minHeight: 90)
            }
        }
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Both properties must be read unconditionally: a short-circuited read
    /// here means no observation dependency gets registered, and the layout
    /// never re-evaluates when the unread property changes (WIN-3 heisenbug —
    /// a debug-log line reading both made the pin work; removing it broke it).
    private func pinnedPreviewHeight(paneHeight: CGFloat) -> CGFloat? {
        let contentHeight = previewContentHeight
        let showingDecoded = model.showDecodedSource
        guard showingDecoded, let contentHeight else { return nil }
        return min(contentHeight, paneHeight * 0.25)
    }

    private func announcePreviewIsNonInteractive() {
        // The in-page toast (CTRL-2) is invisible to VoiceOver; announce the
        // same way copySnippet() announces "Copied" (passed test 16.4).
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: UIStrings.previewNonInteractive])
    }

}
