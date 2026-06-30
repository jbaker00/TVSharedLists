import CloudKit
import SwiftUI

struct ManageListView: View {
    let list: TVList
    @ObservedObject var viewModel: TVShowViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isLoadingShare = false
    @State private var shareData: (CKShare, CKContainer)?
    @State private var showSharing = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    init(list: TVList, viewModel: TVShowViewModel) {
        self.list = list
        self.viewModel = viewModel
        _name = State(initialValue: list.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                if list.isOwned {
                    nameSection
                    if list.isShareable { sharingSection }
                    if list.id != TVList.myShowsID { dangerSection }
                } else {
                    sharedInfoSection
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(list.isOwned ? "Manage List" : "List Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showSharing) {
            if let (share, container) = shareData {
                CloudSharingView(share: share, container: container) {
                    showSharing = false
                    Task { await viewModel.manager.refreshIfNeeded() }
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("List name", text: $name)
                .onSubmit { saveNameIfChanged() }
            if name != list.name {
                Button("Save Name") { saveNameIfChanged() }
            }
        }
    }

    private var sharingSection: some View {
        Section {
            Button {
                Task { await openSharing() }
            } label: {
                HStack {
                    Label("Share this List", systemImage: "person.badge.plus")
                    Spacer()
                    if isLoadingShare { ProgressView().scaleEffect(0.8) }
                }
            }
            .disabled(isLoadingShare)
        } header: {
            Text("Sharing")
        } footer: {
            Text("Invite people by Apple ID. They'll see and optionally add to this list on their devices.")
        }
    }

    private var sharedInfoSection: some View {
        Section("Shared With You By") {
            if let owner = list.ownerDisplayName {
                Label(owner, systemImage: "person.circle")
            }
            Label(list.canEdit ? "You can view and add" : "View only",
                  systemImage: list.canEdit ? "pencil" : "eye")
                .foregroundStyle(.secondary)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(list.isOwned ? "Delete List" : "Remove from My Lists",
                      systemImage: "trash")
            }
        }
        .confirmationDialog(
            list.isOwned
                ? "Delete \"\(list.name)\"? All shows in this list will be deleted."
                : "Remove \"\(list.name)\" from your lists?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(list.isOwned ? "Delete List" : "Remove", role: .destructive) {
                Task {
                    do {
                        try await viewModel.manager.deleteList(list)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveNameIfChanged() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != list.name else { return }
        Task {
            do { try await viewModel.manager.renameList(list, to: trimmed) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func openSharing() async {
        isLoadingShare = true
        defer { isLoadingShare = false }
        do {
            shareData = try await viewModel.manager.getOrCreateShare(for: list)
            showSharing = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
