import CoreImage
import Foundation
import Observation

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

    public var today: [Moment] { moments(on: Moment.dayKey(for: Date())) }

    public func moments(on dayKey: String) -> [Moment] {
        moments.filter { $0.dayKey == dayKey }.sorted { $0.capturedAt < $1.capturedAt }
    }

    public var dayKeys: [String] {
        Array(Set(moments.map(\.dayKey))).sorted(by: >)
    }

    public var finishedDayKeys: [String] {
        let today = Moment.dayKey(for: Date())
        return dayKeys.filter { $0 < today }
    }

    public func add(_ moment: Moment) {

        guard !moments.contains(where: { $0.fileName == moment.fileName }) else { return }
        moments.append(moment)
        save()
    }

    public func updateColor(_ id: Moment.ID, to hex: String) {
        guard let i = moments.firstIndex(where: { $0.id == id }) else { return }
        let old = moments[i]
        moments[i] = Moment(id: old.id, capturedAt: old.capturedAt, colorHex: hex,
                            fileName: old.fileName, source: old.source, colorWasChosen: true)
        save()
    }

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

    public func removeAll() {
        moments = []
        save()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: ShotStore.directory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files { try? fm.removeItem(at: f) }
    }

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
