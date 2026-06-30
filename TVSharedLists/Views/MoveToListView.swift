import SwiftUI

struct MoveToListView: View {
    let show: TVShow
    @ObservedObject var viewModel: TVShowViewModel
    @Environment(\.dismiss) private var dismiss

    private var availableLists: [TVList] {
        viewModel.lists.filter { $0.id != show.listID && $0.canEdit }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableLists) { list in
                        Button {
                            viewModel.moveShow(show, toList: list)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: list.isOwned ? "list.bullet" : "person.2")
                                    .foregroundStyle(.indigo)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .foregroundStyle(.primary)
                                    if let owner = list.ownerDisplayName {
                                        Text("Shared by \(owner)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Move \"\(show.title)\" to")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if availableLists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No Other Lists")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Text("Create another list first to move shows between them.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
    }
}
