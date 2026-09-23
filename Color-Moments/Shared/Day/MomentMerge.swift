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

    /// 같은 사진이 두 기록일 때 a 를 남기나. id 만 본다 — capturedAt 은 저장·CloudKit 정밀도가 기기마다 달라 서로 이긴다고 판정할 수 있다.
    public static func keeps(_ a: Moment, over b: Moment) -> Bool {
        a.id.uuidString < b.id.uuidString
    }

    /// 같은 사진 두 기록을 하나로. 인자 순서와 무관하게 같은 결과라 두 기기가 같은 기록으로 모인다.
    public static func combine(_ a: Moment, _ b: Moment) -> Moment {
        let (winner, loser) = keeps(a, over: b) ? (a, b) : (b, a)
        let wordSide = winner.word != nil ? winner : loser
        let device = winner.assetID != nil || loser.assetID == nil ? winner : loser
        return Moment(id: winner.id, capturedAt: winner.capturedAt, colorHex: winner.colorHex,
                      fileName: device.fileName, source: winner.source,
                      word: wordSide.word, labels: wordSide.labels ?? winner.labels ?? loser.labels,
                      assetID: device.assetID, place: winner.place ?? loser.place,
                      addedAt: winner.addedAt ?? loser.addedAt, batchID: winner.batchID ?? loser.batchID,
                      originalName: device.originalName, cloudID: winner.cloudID ?? loser.cloudID)
    }

    public static func syncedEqual(_ a: Moment, _ b: Moment) -> Bool {
        a.id == b.id && sameInstant(a.capturedAt, b.capturedAt) && a.colorHex == b.colorHex && a.source == b.source
            && a.word == b.word && a.labels == b.labels && a.place == b.place && sameInstant(a.addedAt, b.addedAt)
            && a.batchID == b.batchID && a.cloudID == b.cloudID
    }

    // 반올림 비교는 days.json(밀리초 절삭)과 CloudKit 값이 경계에서 1ms 갈려 끝없이 다시 올린다 — 차이로 본다.
    private static func sameInstant(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return abs(a.timeIntervalSince(b)) < 0.001
    }
}
