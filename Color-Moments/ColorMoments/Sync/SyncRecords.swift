import CloudKit

enum SyncRecords {
    static let zoneID = CKRecordZone.ID(zoneName: "Mongdol", ownerName: CKCurrentUserDefaultName)
    static let momentType = "Moment"
    static let dayType = "Day"

    enum Ref { case moment(UUID), day(String) }

    struct DayState: Equatable {
        let dayKey: String
        let closedAt: Date?
        let gifted: Bool
    }

    static func recordID(moment id: UUID) -> CKRecord.ID { CKRecord.ID(recordName: "m-" + id.uuidString, zoneID: zoneID) }
    static func recordID(day key: String) -> CKRecord.ID { CKRecord.ID(recordName: "d-" + key, zoneID: zoneID) }

    static func ref(_ id: CKRecord.ID) -> Ref? {
        let name = id.recordName
        if name.hasPrefix("m-"), let uuid = UUID(uuidString: String(name.dropFirst(2))) { return .moment(uuid) }
        if name.hasPrefix("d-") { return .day(String(name.dropFirst(2))) }
        return nil
    }

    static func fill(_ r: CKRecord, with m: Moment) {
        r["capturedAt"] = m.capturedAt
        r["colorHex"] = m.colorHex
        r["source"] = m.source.rawValue
        r["wordID"] = m.word?.wordID
        r["word"] = m.word?.word
        r["meaning"] = m.word?.meaning
        r["labels"] = m.labels
        // CloudKit 이 빈 배열을 nil 로 돌려줄 수 있다 — 「분류했는데 없음」을 따로 남긴다.
        r["labelsEmpty"] = m.labels?.isEmpty == true ? 1 : nil
        r["latitude"] = m.place?.latitude
        r["longitude"] = m.place?.longitude
        r["accuracy"] = m.place?.accuracy
        r["placeName"] = m.place?.name
        r["addedAt"] = m.addedAt
        r["batchID"] = m.batchID?.uuidString
        r["cloudID"] = m.cloudID
    }

    static func moment(from r: CKRecord) -> Moment? {
        guard case .moment(let id) = ref(r.recordID),
              let capturedAt = r["capturedAt"] as? Date,
              let colorHex = r["colorHex"] as? String,
              let source = (r["source"] as? String).flatMap(Moment.Source.init(rawValue:)) else { return nil }
        let labels: [String]? = r["labels"] as? [String]
            ?? ((r["labelsEmpty"] as? Int) == 1 || r["wordID"] != nil ? [] : nil)
        // 로컬 DayStore.load() 와 같은 규칙 — labels 없이 word 만 있는 상태를 만들지 않는다.
        let word: PhotoWord? = {
            guard labels != nil, let wid = r["wordID"] as? String, let w = r["word"] as? String,
                  let meaning = r["meaning"] as? String else { return nil }
            return PhotoWord(wordID: wid, word: w, meaning: meaning)
        }()
        let place: Place? = {
            guard let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double,
                  let acc = r["accuracy"] as? Double else { return nil }
            return Place(latitude: lat, longitude: lon, accuracy: acc, name: r["placeName"] as? String)
        }()
        let cloudID = r["cloudID"] as? String
        return Moment(id: id, capturedAt: capturedAt, colorHex: colorHex,
                      fileName: Moment.receivedFileName(cloudID: cloudID, id: id), source: source,
                      word: word, labels: labels, place: place,
                      addedAt: r["addedAt"] as? Date,
                      batchID: (r["batchID"] as? String).flatMap(UUID.init(uuidString:)), cloudID: cloudID)
    }

    static func fill(_ r: CKRecord, with d: DayState) {
        r["closedAt"] = d.closedAt
        r["gifted"] = d.gifted ? 1 : 0
    }

    static func day(from r: CKRecord) -> DayState? {
        guard case .day(let key) = ref(r.recordID) else { return nil }
        return DayState(dayKey: key, closedAt: r["closedAt"] as? Date, gifted: (r["gifted"] as? Int ?? 0) != 0)
    }
}
