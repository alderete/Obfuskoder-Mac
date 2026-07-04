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
            // Empty link text defaults to the email address: shown as ghost
            // text, accepted into the field with Tab, and used by the encoder.
            field(UIStrings.linkTextLabel, hint: UIStrings.linkTextHint,
                  text: $model.form.basic.linkText,
                  placeholder: trimmedEmail,
                  tabCompletion: { [model] in model.form.basic.email
                      .trimmingCharacters(in: .whitespacesAndNewlines) })
            field(UIStrings.linkTitleLabel, hint: UIStrings.linkTitleHint,
                  text: $model.form.basic.linkTitle, optional: true)
            field(UIStrings.subjectLabel, hint: UIStrings.subjectHint,
                  text: $model.form.basic.subject, optional: true)
        }
    }

    private var trimmedEmail: String {
        model.form.basic.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func field(_ label: String, hint: String, text: Binding<String>,
                       optional: Bool = false, placeholder: String = "",
                       tabCompletion: (() -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.appHeadline)
                if optional {
                    Text("(\(UIStrings.optional))").foregroundStyle(.tertiary).font(.caption)
                }
                FieldHint(fieldLabel: label, hint: hint)
            }
            MacTextField(text: text, placeholder: placeholder,
                         font: .appFieldFont, tabCompletion: tabCompletion)
                .accessibilityLabel(Text(label))
        }
    }
}
