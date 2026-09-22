import CoreImage
import Foundation
import Observation

/// 하루 단위로 순간을 모아두는 저장소.
///
/// JSON 한 장이다. SwiftData 를 쓰지 않는 이유: 기록이 하루 수십 개 규모라 쿼리가 필요 없고,
/// 파일을 그대로 열어볼 수 있어야 디버깅과 이관이 쉽다. 규모가 커지면 그때 바꾼다.
///
/// **잠긴 확장은 이 저장소에 못 쓴다.** 확장은 사진만 `sessionContentURL` 에 남기고,
/// 앱이 열릴 때 `CaptureInbox` 가 들여오면서 색을 다시 뽑아 여기에 기록한다.
@Observable
public final class DayStore {

    public private(set) var moments: [Moment] = []

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("days.json")
        load()
    }

    // MARK: 읽기

    /// 오늘(새벽 4시 경계 기준)의 순간들. 이른 것부터.
    public var today: [Moment] { moments(on: Moment.dayKey(for: Date())) }

    public func moments(on dayKey: String) -> [Moment] {
        moments.filter { $0.dayKey == dayKey }.sorted { $0.capturedAt < $1.capturedAt }
    }

    /// 기록이 있는 날들. 최근 날짜부터.
    public var dayKeys: [String] {
        Array(Set(moments.map(\.dayKey))).sorted(by: >)
    }

    /// 끝난 하루들. 최근 날짜부터. **오늘은 빠진다.**
    ///
    /// 수집물로 보여줄 수 있는 것과 아직 아닌 것을 가른다. 오늘은 자정에 증정되면서
    /// 비로소 수집물이 된다 — 그 전에 줄에 얹으면 색을 미리 볼 수 있게 된다.
    public var finishedDayKeys: [String] {
        let today = Moment.dayKey(for: Date())
        return dayKeys.filter { $0 < today }
    }

    // MARK: 쓰기

    public func add(_ moment: Moment) {
        // 같은 파일이 두 번 들어오는 것을 막는다 (수신함이 재실행될 수 있다).
        guard !moments.contains(where: { $0.fileName == moment.fileName }) else { return }
        moments.append(moment)
        save()
    }

    /// 탭 보정. 사용자가 고른 색으로 바꾸고 «직접 고름» 표시를 남긴다.
    public func updateColor(_ id: Moment.ID, to hex: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }) else { return }
        let old = moments[i]
        moments[i] = Moment(id: old.id, capturedAt: old.capturedAt, colorHex: hex,
                            fileName: old.fileName, source: old.source, colorWasChosen: true)
        save()
    }

    /// 탭 보정을 물린다. 색을 자동값으로 다시 뽑고 «직접 고름» 표시를 지운다.
    ///
    /// 저장된 색을 되돌리는 게 아니라 **사진에서 다시 뽑는다** — 추출기가 결정론적이라
    /// 같은 사진은 항상 같은 색을 내므로, 자동값을 따로 보관할 필요가 없다.
    public func revertColor(_ id: Moment.ID) {
        guard let i = moments.firstIndex(where: { $0.id == id }) else { return }
        let old = moments[i]
        let url = ShotStore.directory.appendingPathComponent(old.fileName)
        guard let data = try? Data(contentsOf: url),
              let image = CIImage(data: data) else { return }
        let hex = ColorExtractor.symbolicColor(for: image).hex
        moments[i] = Moment(id: old.id, capturedAt: old.capturedAt, colorHex: hex,
                            fileName: old.fileName, source: old.source, colorWasChosen: false)
        save()
    }

    /// 전부 지운다. 기록과 사진 파일 둘 다.
    public func removeAll() {
        moments = []
        save()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: ShotStore.directory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files { try? fm.removeItem(at: f) }
    }

    // MARK: 영속화

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        moments = (try? decoder.decode([Moment].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(moments) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
