import SwiftUI

struct CategoryPanel: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Categories")
                        .font(.headline)
                    Text("TidyDrop will sort files into these folders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !store.lastAddedAICategories.isEmpty {
                    Text("\(store.lastAddedAICategories.count) AI-added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.addCategory()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if store.categories.isEmpty {
                ContentUnavailableView("No categories defined", systemImage: "rectangle.3.group", description: Text("Choose a template or add a category before classification."))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(store.categories) { category in
                        CategoryCard(store: store, category: category)
                    }
                }
            }
        }
    }
}

private struct CategoryCard: View {
    @Bindable var store: AppStore
    @State var category: Category

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Name", text: $category.name)
                    .font(.headline)
                Button {
                    store.removeCategory(category)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            TextField("Description", text: $category.description)
            TextField("Rules", text: $category.rules, axis: .vertical)
                .lineLimit(2...4)
            if category.id == "review" {
                Text("Files TidyDrop is unsure about.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textFieldStyle(.plain)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: category) { _, newValue in
            store.updateCategory(newValue)
        }
    }
}
