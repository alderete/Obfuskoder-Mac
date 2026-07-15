import SwiftUI
import ObfuskoderKit

struct AdvancedFormView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(UIStrings.advancedLabel).font(.appHeadline)
                FieldHint(fieldLabel: UIStrings.advancedLabel, hint: UIStrings.advancedHint)
            }
            MacTextEditor(text: $model.form.advanced,
                          onEdit: { model.handleFieldEdit(.advancedHTML, $0) },
                          onSelection: { model.noteSelection(.advancedHTML, $0) },
                          onFocus: { model.noteFocus(.advancedHTML) },
                          onBlur: { model.noteBlur(.advancedHTML) },
                          pendingRestore: model.pendingRestore,
                          onConsumeRestore: { model.consumePendingRestore() })
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel(Text(UIStrings.advancedLabel))
        }
    }
}
