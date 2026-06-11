import SwiftUI

/// SPEC-CLI §11.2: brief in-app instructions for the obfuskode tool.
/// Deliberately short — full detail lives in `obfuskode --help`.
struct CLIHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.cliHelpIntro)
            Text(UIStrings.cliHelpInstall)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "obfuskode --email sue@example.com --link-text \"Email Sue\"")
                Text(verbatim: "obfuskode --html '<a href=\"mailto:sue@example.com\">contact</a>'")
                Text(verbatim: "pbpaste | obfuskode | pbcopy")
            }
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
            Text(UIStrings.cliHelpOutro)
        }
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    CLIHelpView()
}
