import CloudKit

/// recordName → 서버가 준 시스템 필드(변경 태그). 없으면 새 기록으로 올려 충돌 한 번을 더 치른다.
@MainActor
final class SystemFieldsCache {

    private let writer: CoalescingWriter
    private var fields: [String: Data]

    init(fileURL: URL) {
        writer = CoalescingWriter.forFile(fileURL)
        writer.flush()
        fields = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([String: Data].self, from: $0) } ?? [:]
    }

    var count: Int { fields.count }

    func record(_ id: CKRecord.ID, type: String) -> CKRecord {
        if let data = fields[id.recordName],
           let coder = try? NSKeyedUnarchiver(forReadingFrom: data) {
            coder.requiresSecureCoding = true
            defer { coder.finishDecoding() }
            if let r = CKRecord(coder: coder) { return r }
        }
        return CKRecord(recordType: type, recordID: id)
    }

    func remember(_ r: CKRecord) { remember(Self.archive(r), for: r.recordID.recordName) }

    func remember(_ archived: Data, for recordName: String) { fields[recordName] = archived }

    /// 3,000건에 90ms 가까이 든다 — 받은 묶음은 메인 밖에서 이걸로 굽고 remember(_:for:) 로 넣는다.
    nonisolated static func archive(_ r: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    func forget(_ id: CKRecord.ID) { fields[id.recordName] = nil }

    func removeAll() { fields = [:] }

    /// 인코딩·쓰기는 백그라운드 — 묶음마다 누적 전체를 메인에서 쓰면 수신량 제곱으로 느려진다.
    func persist() {
        let snapshot = fields
        writer.write { try? JSONEncoder().encode(snapshot) }
    }

    func flush() { writer.flush() }

    /// 이 파일 쓰기 뒤에 이어 쓸 때 — 백그라운드 큐에서 부를 수 있게 쓰기 객체를 넘긴다.
    var fileWriter: CoalescingWriter { writer }
}
