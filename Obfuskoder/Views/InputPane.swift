import SwiftUI
import ObfuskoderKit

struct InputPane: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.form.mode {
            case .basic: BasicFormView(model: model)
            case .advanced: AdvancedFormView(model: model)
            }
            Spacer(minLength: 0)
            EmptyView() // TODO(Task 27): replace with SavedValuesBar(model: model)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
