import Foundation

public enum StoreChange: Equatable, Sendable {
    case upsert(Moment.ID)
    case delete(Moment.ID)
}

public enum MomentMerge {

    /// remote = 서버. fileName·assetID·originalName 은 이 기기 전용이라 local 것을 쓴다.
    public static func merge(local: Moment, remote: Moment) -> Moment {
        let useRemoteWord = remote.word != nil
        return Moment(id: remote.id, capturedAt: remote.capturedAt, colorHex: remote.colorHex,
                      fileName: local.fileName, source: remote.source,
                      word: useRemoteWord ? remote.word : local.word,
                      labels: useRemoteWord ? remote.labels : (local.labels ?? remote.labels),
                      assetID: local.assetID, place: remote.place ?? local.place,
                      addedAt: remote.addedAt ?? local.addedAt, batchID: remote.batchID ?? local.batchID,
                      originalName: local.originalName, cloudID: remote.cloudID ?? local.cloudID)
    }

    /// 같은 사진이 두 기록일 때 a 를 남기나. 두 기기가 따로 계산해도 같은 답이어야 한다.
    public static func keeps(_ a: Moment, over b: Moment) -> Bool {
        if a.capturedAt != b.capturedAt { return a.capturedAt < b.capturedAt }
        return a.id.uuidString < b.id.uuidString
    }

    public static func syncedEqual(_ a: Moment, _ b: Moment) -> Bool {
        a.id == b.id && a.capturedAt == b.capturedAt && a.colorHex == b.colorHex && a.source == b.source
            && a.word == b.word && a.labels == b.labels && a.place == b.place && a.addedAt == b.addedAt
            && a.batchID == b.batchID && a.cloudID == b.cloudID
    }
}
