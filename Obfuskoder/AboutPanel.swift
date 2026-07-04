import AppKit
import ObfuskoderKit

/// The standard About panel, with custom credits: tagline, attribution, and a
/// link to the project page (MENU-1). Name, icon, version, and copyright come
/// from Info.plist as usual.
@MainActor
enum AboutPanel {
    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(string: UIStrings.aboutTagline + "\n", attributes: base))
        credits.append(NSAttributedString(string: UIStrings.aboutAttribution + "\n", attributes: base))
        if let url = URL(string: AppConfig.projectPageURL) {
            var linkAttributes = base
            linkAttributes[.link] = url
            let display = url.host().map { $0 + url.path() } ?? AppConfig.projectPageURL
            credits.append(NSAttributedString(string: display, attributes: linkAttributes))
        }
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
