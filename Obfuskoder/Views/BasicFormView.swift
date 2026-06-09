import SwiftUI
import ObfuskoderKit

struct BasicFormView: View {
    @Bindable var model: AppModel

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 10) {
            row(UIStrings.emailLabel, hint: UIStrings.emailHint,
                text: $model.form.basic.email)
            row(UIStrings.linkTextLabel, hint: UIStrings.linkTextHint,
                text: $model.form.basic.linkText)
            row(UIStrings.linkTitleLabel, hint: UIStrings.linkTitleHint,
                text: $model.form.basic.linkTitle, optional: true)
            row(UIStrings.subjectLabel, hint: UIStrings.subjectHint,
                text: $model.form.basic.subject, optional: true)
        }
    }

    @ViewBuilder
    private func row(_ label: String, hint: String, text: Binding<String>, optional: Bool = false) -> some View {
        GridRow {
            HStack(spacing: 4) {
                Text(label)
                if optional {
                    Text("(\(UIStrings.optional))").foregroundStyle(.tertiary).font(.caption)
                }
            }
            .gridColumnAlignment(.trailing)

            HStack(spacing: 6) {
                MacTextField(text: text)
                    .frame(minWidth: 220)
                    .accessibilityLabel(Text(label))
                FieldHint(fieldLabel: label, hint: hint)
            }
        }
    }
}
