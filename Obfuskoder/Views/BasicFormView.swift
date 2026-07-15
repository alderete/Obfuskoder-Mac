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
                  id: .email, text: $model.form.basic.email)
            // Empty link text defaults to the email address: shown as ghost
            // text, accepted into the field with Tab, and used by the encoder.
            field(UIStrings.linkTextLabel, hint: UIStrings.linkTextHint,
                  id: .linkText, text: $model.form.basic.linkText,
                  placeholder: trimmedEmail,
                  tabCompletion: { [model] in model.form.basic.email
                      .trimmingCharacters(in: .whitespacesAndNewlines) })
            field(UIStrings.linkTitleLabel, hint: UIStrings.linkTitleHint,
                  id: .linkTitle, text: $model.form.basic.linkTitle, optional: true)
            field(UIStrings.subjectLabel, hint: UIStrings.subjectHint,
                  id: .subject, text: $model.form.basic.subject, optional: true)
        }
    }

    private var trimmedEmail: String {
        model.form.basic.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func field(_ label: String, hint: String, id: FieldID, text: Binding<String>,
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
            MacTextField(text: text, field: id, placeholder: placeholder,
                         font: .appFieldFont, tabCompletion: tabCompletion,
                         onEdit: { model.handleFieldEdit(id, $0) },
                         onSelection: { model.noteSelection(id, $0) },
                         onFocus: { model.noteFocus(id) },
                         onBlur: { model.noteBlur(id) },
                         pendingRestore: model.pendingRestore,
                         onConsumeRestore: { model.consumePendingRestore() })
                .accessibilityLabel(Text(label))
        }
    }
}
