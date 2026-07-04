import SwiftUI
import ObfuskoderKit

/// Basic-mode form. Field groups mirror AdvancedFormView's pattern exactly —
/// bold label with its hint beside it, control underneath — so the two modes
/// present one consistent layout (FORM-1/FORM-2).
struct BasicFormView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field(UIStrings.emailLabel, hint: UIStrings.emailHint,
                  text: $model.form.basic.email)
            field(UIStrings.linkTextLabel, hint: UIStrings.linkTextHint,
                  text: $model.form.basic.linkText)
            field(UIStrings.linkTitleLabel, hint: UIStrings.linkTitleHint,
                  text: $model.form.basic.linkTitle, optional: true)
            field(UIStrings.subjectLabel, hint: UIStrings.subjectHint,
                  text: $model.form.basic.subject, optional: true)
        }
    }

    private func field(_ label: String, hint: String, text: Binding<String>,
                       optional: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.appHeadline)
                if optional {
                    Text("(\(UIStrings.optional))").foregroundStyle(.tertiary).font(.caption)
                }
                FieldHint(fieldLabel: label, hint: hint)
            }
            MacTextField(text: text, font: .appFieldFont)
                .accessibilityLabel(Text(label))
        }
    }
}
