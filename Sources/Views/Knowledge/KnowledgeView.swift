import SwiftUI
import GRDB

struct KnowledgeView: View {
    @EnvironmentObject var appState: AppState
    @State private var items: [Knowledge] = []
    @State private var authors: [Int64: Member] = [:]
    @State private var searchText = ""
    @State private var selectedCategory: KnowledgeCategory?
    @State private var selectedItem: Knowledge?

    var filteredItems: [Knowledge] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.content.localizedCaseInsensitiveContains(searchText)
            let matchesCat = selectedCategory == nil || item.category == selectedCategory
            return matchesSearch && matchesCat
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Knowledge Base")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search knowledge...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(KnowledgeCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.displayName, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                List(filteredItems, selection: $selectedItem) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            Text(item.category.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            if let authorId = item.authorId, let author = authors[authorId] {
                                Text(author.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(item)
                }
                .listStyle(.inset)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            if let item = selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.title)
                            .font(.title)
                            .fontWeight(.bold)
                        HStack(spacing: 8) {
                            Text(item.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            if let authorId = item.authorId, let author = authors[authorId] {
                                HStack(spacing: 4) {
                                    AvatarView(name: author.name, size: 20, avatarUrl: author.avatarUrl)
                                    Text(author.name)
                                        .font(.caption)
                                }
                            }
                        }
                        Divider()
                        Text(item.content)
                            .font(.body)
                            .lineSpacing(6)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView("Select an Article", systemImage: "book", description: Text("Choose from the knowledge base"))
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        do {
            items = try appState.database.read { db in
                try Knowledge.filter(Knowledge.Columns.isPublished == true).order(Knowledge.Columns.createdAt.desc).fetchAll(db)
            }
            let memberList = try appState.database.read { db in
                try Member.fetchAll(db)
            }
            authors = Dictionary(uniqueKeysWithValues: memberList.compactMap { m in
                m.id.map { ($0, m) }
            })
        } catch {
            print("Load knowledge error: \(error)")
        }
    }
}
