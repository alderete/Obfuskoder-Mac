import SwiftUI

/// Compact in-app help (MENU-4), parallel to CLIHelpView. Content distilled
/// from README.md and SPECIFICATION.md §1–2.
struct ObfuskoderHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(inlineMarkdown: UIStrings.appHelpIntro)
            Text(inlineMarkdown: UIStrings.appHelpModes)
            Text(inlineMarkdown: UIStrings.appHelpPreview)
            Text(inlineMarkdown: UIStrings.appHelpGuarantee)
            Text(inlineMarkdown: UIStrings.appHelpSaved)
            Text(inlineMarkdown: UIStrings.appHelpPrivacy)
            Text(inlineMarkdown: UIStrings.appHelpCLIPointer)
        }
        // Fixed width + vertical fixedSize so the window is measured for the
        // fully wrapped text (same trap as the FORM-5 popover).
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    ObfuskoderHelpView()
}
