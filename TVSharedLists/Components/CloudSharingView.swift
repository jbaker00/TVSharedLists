import CloudKit
import SwiftUI

#if !targetEnvironment(macCatalyst)
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onDone: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let ctrl = UICloudSharingController(share: share, container: container)
        ctrl.availablePermissions = [.allowPrivate, .allowReadOnly, .allowReadWrite]
        ctrl.delegate = context.coordinator
        ctrl.modalPresentationStyle = .formSheet
        return ctrl
    }

    func updateUIViewController(_: UICloudSharingController, context: Context) {}

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var onDone: (() -> Void)?
        init(onDone: (() -> Void)?) { self.onDone = onDone }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("[TVSharedLists] Share save error: \(error)")
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onDone?() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDone?() }
        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }
    }
}
#else
struct CloudSharingView: View {
    let share: CKShare
    let container: CKContainer
    var onDone: (() -> Void)?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "person.badge.plus").font(.system(size: 52)).foregroundStyle(.indigo)
                Text("Share this List").font(.title2.bold())
                if let url = share.url {
                    HStack(spacing: 8) {
                        Text(url.absoluteString).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Button {
                            UIPasteboard.general.string = url.absoluteString
                            copied = true
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                        }
                        .foregroundStyle(copied ? .green : .indigo)
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(8).padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Share List").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { onDone?() } } }
        }
    }
}
#endif
