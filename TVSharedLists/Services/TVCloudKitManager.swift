import CloudKit
import FirebaseAnalytics
import Foundation

enum SyncStatus {
    case idle, syncing, error(String), synced(Date)

    var icon: String {
        switch self {
        case .idle:    return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .error:   return "exclamationmark.icloud"
        case .synced:  return "checkmark.icloud.fill"
        }
    }

    var label: String {
        switch self {
        case .idle:           return "Not synced yet"
        case .syncing:        return "Syncing…"
        case .error(let msg): return msg
        case .synced(let d):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Synced \(f.localizedString(for: d, relativeTo: Date()))"
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

@MainActor
class TVCloudKitManager: ObservableObject {
    @Published var lists: [TVList] = [.myShows]
    @Published var shows: [TVShow] = []
    @Published var iCloudAvailable = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var selectedList: TVList = .myShows

    private let ckContainer = CKContainer(identifier: "iCloud.com.jamesbaker.TVSharedLists")
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDB:  CKDatabase { ckContainer.sharedCloudDatabase }

    private let cacheURL: URL
    private let pendingDeletesURL: URL
    private var pendingDeletes: [PendingDelete] = []
    private var changeTokens: [String: CKServerChangeToken] = [:]

    struct PendingDelete: Codable {
        let recordName: String
        let listID: String
        let listOwnerID: String
    }

    // MARK: - Local-only mode

    var localOnly: Bool {
        get { UserDefaults.standard.bool(forKey: "tvlist_localOnly") }
        set {
            let old = UserDefaults.standard.bool(forKey: "tvlist_localOnly")
            guard old != newValue else { return }
            UserDefaults.standard.set(newValue, forKey: "tvlist_localOnly")
            if newValue {
                // Switched to local — persist current shows to the JSON file
                writeCache(shows)
            } else {
                // Switched to iCloud — push everything to CloudKit
                Task { await migrateLocalToCloudKit() }
            }
        }
    }

    var showsForSelectedList: [TVShow] {
        shows
            .filter { $0.listID == selectedList.id }
            .sorted { $0.addedAt > $1.addedAt }
    }

    // MARK: - Init

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        cacheURL = support.appendingPathComponent("tvshows_cache.json")
        pendingDeletesURL = support.appendingPathComponent("tvshows_pending_deletes.json")

        shows = loadCache()
        pendingDeletes = loadPendingDeletes()
        loadChangeTokens()

        NotificationCenter.default.addObserver(forName: .tvCloudKitShareAccepted,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { await self?.refreshIfNeeded() }
        }
    }

    // MARK: - Sync

    func refreshIfNeeded() async {
        if localOnly {
            if shows.isEmpty { shows = loadLocalFallback() }
            return
        }
        do {
            let status = try await ckContainer.accountStatus()
            iCloudAvailable = (status == .available)
            guard iCloudAvailable else {
                syncStatus = .error("iCloud not available — sign in under Settings > [your name]")
                // Still show cached data
                if shows.isEmpty { shows = loadLocalFallback() }
                return
            }
            syncStatus = .syncing
            await discoverLists()
            await flushPendingDeletes()
            await fetchAllChanges()
            await migrateLegacyIfNeeded()
            syncStatus = .synced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
            if shows.isEmpty { shows = loadLocalFallback() }
        }
    }

    func clearError() {
        if case .error = syncStatus { syncStatus = .idle }
    }

    // MARK: - List discovery

    private func discoverLists() async {
        do {
            var discovered: [TVList] = [.myShows]

            let privateZones = try await privateDB.allRecordZones()
            for zone in privateZones where zone.zoneID.zoneName != TVList.myShowsID {
                let metaID = CKRecord.ID(recordName: "metadata", zoneID: zone.zoneID)
                let name = (try? await privateDB.record(for: metaID))?["name"] as? String ?? "My List"
                discovered.append(TVList(ownedZone: zone, name: name))
            }

            let sharedZones = try await sharedDB.allRecordZones()
            for zone in sharedZones {
                let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)
                let share = try? await sharedDB.record(for: shareID) as? CKShare
                discovered.append(TVList(sharedZone: zone, share: share))
            }

            lists = discovered
            // Keep selectedList in sync with the freshly fetched version
            if let updated = lists.first(where: { $0.id == selectedList.id }) {
                selectedList = updated
            } else {
                selectedList = .myShows
            }
        } catch {
            print("[TVSharedLists] List discovery error: \(error)")
        }
    }

    // MARK: - List management (owner only)

    func createList(name: String) async throws {
        let zone = CKRecordZone(zoneName: UUID().uuidString)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
        let meta = CKRecord(recordType: "ListMetadata",
                            recordID: CKRecord.ID(recordName: "metadata", zoneID: zone.zoneID))
        meta["name"] = name as NSString
        _ = try await privateDB.modifyRecords(saving: [meta], deleting: [], savePolicy: .allKeys)
        lists.append(TVList(ownedZone: zone, name: name))
        Analytics.logEvent("list_created", parameters: [
            "list_count": lists.count,
        ])
    }

    func renameList(_ list: TVList, to name: String) async throws {
        guard list.isOwned else { return }
        let metaID = CKRecord.ID(recordName: "metadata", zoneID: list.zoneID)
        let meta: CKRecord
        if let existing = try? await privateDB.record(for: metaID) {
            meta = existing
        } else {
            meta = CKRecord(recordType: "ListMetadata", recordID: metaID)
        }
        meta["name"] = name as NSString
        _ = try await privateDB.modifyRecords(saving: [meta], deleting: [], savePolicy: .allKeys)
        if let idx = lists.firstIndex(where: { $0.id == list.id }) { lists[idx].name = name }
        // Also update share title if shared
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: list.zoneID)
        if let share = try? await privateDB.record(for: shareID) as? CKShare {
            share[CKShare.SystemFieldKey.title] = name as CKRecordValue
            _ = try? await privateDB.modifyRecords(saving: [share], deleting: [], savePolicy: .allKeys)
        }
    }

    func deleteList(_ list: TVList) async throws {
        guard list.isOwned, list.id != TVList.myShowsID else { return }
        _ = try await privateDB.modifyRecordZones(saving: [], deleting: [list.zoneID])
        lists.removeAll { $0.id == list.id }
        shows.removeAll { $0.listID == list.id }
        writeCache(shows)
        if selectedList.id == list.id { selectedList = .myShows }
    }

    func getOrCreateShare(for list: TVList) async throws -> (CKShare, CKContainer) {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: list.zoneID)
        if let existing = try? await privateDB.record(for: shareID) as? CKShare {
            return (existing, ckContainer)
        }
        let share = CKShare(recordZoneID: list.zoneID)
        share[CKShare.SystemFieldKey.title] = list.name as CKRecordValue
        share.publicPermission = .none
        _ = try await privateDB.modifyRecords(saving: [share], deleting: [], savePolicy: .allKeys)
        Analytics.logEvent("list_shared", parameters: [
            "show_count": shows.filter { $0.listID == list.id }.count,
        ])
        return (share, ckContainer)
    }

    func stopSharing(_ list: TVList) async throws {
        guard list.isOwned else { return }
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: list.zoneID)
        _ = try await privateDB.modifyRecords(saving: [], deleting: [shareID])
    }

    // MARK: - Fetch zone changes

    private func fetchAllChanges() async {
        let ownedZoneIDs  = lists.filter { $0.isOwned  }.map { $0.zoneID }
        let sharedZoneIDs = lists.filter { !$0.isOwned }.map { $0.zoneID }
        if !ownedZoneIDs.isEmpty  { await fetchZoneChanges(zoneIDs: ownedZoneIDs,  from: privateDB) }
        if !sharedZoneIDs.isEmpty { await fetchZoneChanges(zoneIDs: sharedZoneIDs, from: sharedDB) }
    }

    private func fetchZoneChanges(zoneIDs: [CKRecordZone.ID], from database: CKDatabase) async {
        let configs = Dictionary(uniqueKeysWithValues: zoneIDs.map { zoneID -> (CKRecordZone.ID, CKFetchRecordZoneChangesOperation.ZoneConfiguration) in
            let cfg = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                previousServerChangeToken: changeTokens[tokenKey(for: zoneID)],
                resultsLimit: nil,
                desiredKeys: nil
            )
            return (zoneID, cfg)
        })

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: zoneIDs,
                configurationsByRecordZoneID: configs
            )
            op.fetchAllChanges = true

            var changedRecords: [CKRecord] = []
            var deletedIDs: [String] = []
            var newTokens: [String: CKServerChangeToken] = [:]

            op.recordWasChangedBlock = { _, result in
                if let record = try? result.get() { changedRecords.append(record) }
            }
            op.recordWithIDWasDeletedBlock = { id, _ in
                deletedIDs.append(id.recordName)
            }
            op.recordZoneFetchResultBlock = { zoneID, result in
                if case .success(let (token, _, _)) = result {
                    newTokens[self.tokenKey(for: zoneID)] = token
                }
            }
            op.fetchRecordZoneChangesResultBlock = { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { continuation.resume(); return }
                    for (key, token) in newTokens { self.changeTokens[key] = token }
                    self.saveChangeTokens()
                    for record in changedRecords {
                        if record.recordType == TVShow.recordType,
                           let show = TVShow(from: record) {
                            self.applyShow(show)
                        } else if record.recordType == "ListMetadata",
                                  let name = record["name"] as? String,
                                  let idx = self.lists.firstIndex(where: { $0.id == record.recordID.zoneID.zoneName }) {
                            self.lists[idx].name = name
                        }
                    }
                    for id in deletedIDs {
                        self.shows.removeAll { $0.id.uuidString == id }
                    }
                    self.shows.sort { $0.addedAt > $1.addedAt }
                    self.writeCache(self.shows)
                    if case .failure(let error as CKError) = result, error.code == .changeTokenExpired {
                        self.changeTokens.removeAll()
                        self.saveChangeTokens()
                    }
                    continuation.resume()
                }
            }
            database.add(op)
        }
    }

    private func applyShow(_ show: TVShow) {
        guard !pendingDeletes.contains(where: { $0.recordName == show.id.uuidString }) else { return }
        if let idx = shows.firstIndex(where: { $0.id == show.id }) {
            shows[idx] = show
        } else {
            shows.append(show)
        }
    }

    // MARK: - Pending deletes

    private func flushPendingDeletes() async {
        guard !pendingDeletes.isEmpty else { return }
        let owned  = pendingDeletes.filter { $0.listOwnerID == CKCurrentUserDefaultName }
        let shared = pendingDeletes.filter { $0.listOwnerID != CKCurrentUserDefaultName }

        func flush(_ batch: [PendingDelete], database: CKDatabase) async {
            let ids = batch.map { d -> CKRecord.ID in
                let zoneID = CKRecordZone.ID(zoneName: d.listID, ownerName: d.listOwnerID)
                return CKRecord.ID(recordName: d.recordName, zoneID: zoneID)
            }
            do {
                _ = try await database.modifyRecords(saving: [], deleting: ids)
                pendingDeletes.removeAll { d in batch.contains { $0.recordName == d.recordName } }
                writePendingDeletes()
            } catch {
                print("[TVSharedLists] Pending delete flush error: \(error)")
            }
        }

        if !owned.isEmpty  { await flush(owned,  database: privateDB) }
        if !shared.isEmpty { await flush(shared, database: sharedDB) }
    }

    // MARK: - Mutations

    func save(show: TVShow) {
        if let idx = shows.firstIndex(where: { $0.id == show.id }) {
            shows[idx] = show
        } else {
            shows.insert(show, at: 0)
        }

        if localOnly {
            writeCache(shows)
            return
        }

        writeCache(shows)
        let list = lists.first { $0.id == show.listID }
        let db = (list?.isOwned ?? true) ? privateDB : sharedDB
        Task { await pushToCloud(show, database: db) }
    }

    func delete(_ show: TVShow) {
        shows.removeAll { $0.id == show.id }

        if localOnly {
            writeCache(shows)
            return
        }

        writeCache(shows)
        let pending = PendingDelete(recordName: show.id.uuidString,
                                   listID: show.listID,
                                   listOwnerID: show.listOwnerID)
        pendingDeletes.append(pending)
        writePendingDeletes()

        let list = lists.first { $0.id == show.listID }
        let db = (list?.isOwned ?? true) ? privateDB : sharedDB
        Task {
            let zoneID = CKRecordZone.ID(zoneName: show.listID, ownerName: show.listOwnerID)
            let recordID = CKRecord.ID(recordName: show.id.uuidString, zoneID: zoneID)
            do {
                _ = try await db.modifyRecords(saving: [], deleting: [recordID])
                pendingDeletes.removeAll { $0.recordName == show.id.uuidString }
                writePendingDeletes()
            } catch {
                print("[TVSharedLists] Delete error (queued for retry): \(error)")
            }
        }
    }

    func move(show: TVShow, toList list: TVList) async {
        guard show.listID != list.id else { return }

        var newShow = show
        newShow.listID = list.id
        newShow.listOwnerID = list.zoneOwnerName

        // Optimistic local update
        if let idx = shows.firstIndex(where: { $0.id == show.id }) {
            shows[idx] = newShow
        }
        writeCache(shows)

        if localOnly { return }

        // Save to new zone first
        let newDB = list.isOwned ? privateDB : sharedDB
        do {
            _ = try await newDB.modifyRecords(saving: [newShow.toCKRecord()], deleting: [], savePolicy: .allKeys)
        } catch {
            // Revert optimistic update
            if let idx = shows.firstIndex(where: { $0.id == newShow.id }) {
                shows[idx] = show
            }
            writeCache(shows)
            print("[TVSharedLists] Move save error: \(error)")
            return
        }

        // Delete from old zone (queue for retry on failure)
        let oldList = lists.first { $0.id == show.listID }
        let oldDB = (oldList?.isOwned ?? true) ? privateDB : sharedDB
        let oldZoneID = CKRecordZone.ID(zoneName: show.listID, ownerName: show.listOwnerID)
        let oldRecordID = CKRecord.ID(recordName: show.id.uuidString, zoneID: oldZoneID)
        do {
            _ = try await oldDB.modifyRecords(saving: [], deleting: [oldRecordID])
        } catch {
            let pending = PendingDelete(recordName: show.id.uuidString,
                                       listID: show.listID, listOwnerID: show.listOwnerID)
            pendingDeletes.append(pending)
            writePendingDeletes()
            print("[TVSharedLists] Move delete queued: \(error)")
        }
    }

    private func pushToCloud(_ show: TVShow, database: CKDatabase) async {
        do {
            _ = try await database.modifyRecords(saving: [show.toCKRecord()], deleting: [], savePolicy: .allKeys)
        } catch {
            print("[TVSharedLists] CloudKit push error: \(error)")
        }
    }

    // MARK: - Migration from old JSON

    private func migrateLegacyIfNeeded() async {
        guard shows.isEmpty else { return }
        let legacyShows = loadLocalFallback()
        guard !legacyShows.isEmpty else { return }
        // Assign all migrated shows to the personal default zone
        for show in legacyShows {
            let mapped = show.inList(.myShows)
            shows.insert(mapped, at: 0)
            await pushToCloud(mapped, database: privateDB)
        }
        writeCache(shows)
        deleteLocalFallbackFiles()
    }

    private func migrateLocalToCloudKit() async {
        syncStatus = .syncing
        do {
            let status = try await ckContainer.accountStatus()
            iCloudAvailable = (status == .available)
            guard iCloudAvailable else {
                syncStatus = .error("iCloud not available — sign in under Settings > [your name]")
                return
            }
            await discoverLists()
            for show in shows {
                await pushToCloud(show, database: privateDB)
            }
            syncStatus = .synced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Local fallback (reads legacy tvshows.json locations)

    private func loadLocalFallback() -> [TVShow] {
        let fm = FileManager.default

        // iCloud Documents container
        if let container = fm.url(forUbiquityContainerIdentifier: nil) {
            let url = container.appendingPathComponent("Documents/tvshows.json")
            if let shows = decodeJSON(from: url), !shows.isEmpty { return shows }
        }

        // Local Documents directory
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvshows.json")
        if let shows = decodeJSON(from: docsURL), !shows.isEmpty { return shows }

        return []
    }

    private func deleteLocalFallbackFiles() {
        let fm = FileManager.default
        if let container = fm.url(forUbiquityContainerIdentifier: nil) {
            try? fm.removeItem(at: container.appendingPathComponent("Documents/tvshows.json"))
        }
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvshows.json")
        try? fm.removeItem(at: docsURL)
    }

    // MARK: - Change tokens

    private func tokenKey(for zoneID: CKRecordZone.ID) -> String {
        "\(zoneID.zoneName)/\(zoneID.ownerName)"
    }

    private func loadChangeTokens() {
        guard let data = UserDefaults.standard.data(forKey: "tvlist_ckChangeTokens"),
              let dict = (try? NSKeyedUnarchiver.unarchivedObject(
                  ofClasses: [NSDictionary.self, NSString.self, CKServerChangeToken.self],
                  from: data
              )) as? [String: CKServerChangeToken]
        else { return }
        changeTokens = dict
    }

    private func saveChangeTokens() {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: changeTokens as NSDictionary,
            requiringSecureCoding: true
        ) else { return }
        UserDefaults.standard.set(data, forKey: "tvlist_ckChangeTokens")
    }

    // MARK: - Local cache

    private func loadCache() -> [TVShow] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TVShow].self, from: data)) ?? []
    }

    private func writeCache(_ items: [TVShow]) {
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        try? encoder.encode(items).write(to: cacheURL, options: .atomic)
    }

    private func loadPendingDeletes() -> [PendingDelete] {
        guard let data = try? Data(contentsOf: pendingDeletesURL) else { return [] }
        return (try? JSONDecoder().decode([PendingDelete].self, from: data)) ?? []
    }

    private func writePendingDeletes() {
        let dir = pendingDeletesURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(pendingDeletes).write(to: pendingDeletesURL, options: .atomic)
    }

    private func decodeJSON(from url: URL) -> [TVShow]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([TVShow].self, from: data)
    }
}
