import CloudKit
import Foundation

struct TVList: Identifiable, Equatable {
    static let myShowsID = "_defaultZone"

    let id: String
    var name: String
    let zoneOwnerName: String
    var isOwned: Bool
    var canEdit: Bool
    var isShareable: Bool
    var ownerDisplayName: String?

    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: id, ownerName: zoneOwnerName)
    }

    static var myShows: TVList {
        TVList(id: myShowsID, name: "My Shows",
               zoneOwnerName: CKCurrentUserDefaultName,
               isOwned: true, canEdit: true, isShareable: false, ownerDisplayName: nil)
    }

    init(id: String, name: String, zoneOwnerName: String,
         isOwned: Bool, canEdit: Bool, isShareable: Bool, ownerDisplayName: String?) {
        self.id = id
        self.name = name
        self.zoneOwnerName = zoneOwnerName
        self.isOwned = isOwned
        self.canEdit = canEdit
        self.isShareable = isShareable
        self.ownerDisplayName = ownerDisplayName
    }

    init(ownedZone zone: CKRecordZone, name: String) {
        self.init(id: zone.zoneID.zoneName, name: name,
                  zoneOwnerName: CKCurrentUserDefaultName,
                  isOwned: true, canEdit: true, isShareable: true, ownerDisplayName: nil)
    }

    init(sharedZone zone: CKRecordZone, share: CKShare?) {
        let title = share?[CKShare.SystemFieldKey.title] as? String ?? "Shared List"
        let permission = share?.currentUserParticipant?.permission ?? .readOnly
        let ownerComponents = share?.owner.userIdentity.nameComponents
        let ownerName = ownerComponents.map { PersonNameComponentsFormatter().string(from: $0) }
        self.init(id: zone.zoneID.zoneName, name: title,
                  zoneOwnerName: zone.zoneID.ownerName,
                  isOwned: false, canEdit: permission == .readWrite,
                  isShareable: false, ownerDisplayName: ownerName)
    }
}
