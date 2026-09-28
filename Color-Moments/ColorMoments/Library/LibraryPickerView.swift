import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LibraryPickerView: View {
    let store: DayStore
    let onDone: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var status: PHAuthorizationStatus?
    // 결과와 섹션은 늘 한 벌로 바꾼다 — 섹션 인덱스는 그 결과에만 맞는다.
    @State private var library: Library?
    @State private var progress: LoadProgress?
    @State private var loading: Task<Void, Never>?
    @State private var selected: Set<String> = []
    @State private var isImporting = false
    @State private var imageManager = PHCachingImageManager()

    private static let gridSpacing: CGFloat = 2

    private struct Library {
        let result: PHFetchResult<PHAsset>
        let sections: [LibrarySection]
    }

    private struct LoadProgress: Equatable {
        let done: Int
        let total: Int
    }

    private struct LoadUpdate: @unchecked Sendable {
        let result: PHFetchResult<PHAsset>
        let sections: [LibrarySection]
        let done: Int
        let total: Int
        let ids: Set<String>?
    }

    var body: some View {
        ZStack {
            Tone.pure.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content
            }
        }
        .task { await load() }
        .onDisappear { loading?.cancel() }
        .interactiveDismissDisabled(isImporting)
    }

    @ViewBuilder
    private var content: some View {
        if status == .authorized || status == .limited {
            if status == .limited { limitedBanner }
            if let library {
                if library.result.count == 0 { emptyState } else { grid(library) }
            } else {
                loadingState
            }
        } else if status == .restricted {
            restrictedState
        } else if status != nil {
            deniedState
        } else {
            Spacer()
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("닫기")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tone.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Tone.hairline, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
            .opacity(isImporting ? 0.4 : 1)

            Spacer()
            Text("사진첩").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tone.primary)
            Spacer()

            Group {
                if isImporting {
                    ProgressView().tint(Tone.primary)
                } else {
                    Button { Task { await importSelected() } } label: {
                        Text("담기 \(selected.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tone.pure)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Tone.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.isEmpty)
                    .opacity(selected.isEmpty ? 0.4 : 1)
                }
            }
            .frame(minWidth: 66)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var limitedBanner: some View {
        Button { presentLimitedPicker() } label: {
            Text("사진을 더 보이게 하기")
                .font(Face.guide)
                .foregroundStyle(Tone.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var restrictedState: some View {
        VStack {
            Spacer()
            Text("이 기기에서는 사진 접근이 제한돼 있어요")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(Tone.secondary)
            Text("사진을 불러오는 중")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
            if let progress { progressLine(progress) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func progressLine(_ p: LoadProgress) -> some View {
        Text("사진 \(p.total.formatted())장 중 \(p.done.formatted())장")
            .font(Face.caption).monospacedDigit()
            .foregroundStyle(Tone.tertiary)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(status == .limited ? "아직 보이게 한 사진이 없어요" : "사진첩이 비어 있어요")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var deniedState: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 6) {
                Text("사진 접근이 꺼져 있어요")
                    .font(Face.guide)
                    .foregroundStyle(Tone.secondary)
                Text("켜고 싶어지면 설정에서 언제든 바꿀 수 있어요")
                    .font(Face.caption)
                    .foregroundStyle(Tone.tertiary)
            }
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("설정 열기")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tone.pure)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Tone.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func grid(_ library: Library) -> some View {
        GeometryReader { geo in
            let side = max(0, (geo.size.width - Self.gridSpacing * 2) / 3)
            let columns = Array(repeating: GridItem(.fixed(side), spacing: Self.gridSpacing), count: 3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(library.sections, id: \.dayKey) { section in
                        Section {
                            LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                                ForEach(section.indices, id: \.self) { i in
                                    let asset = library.result.object(at: i)
                                    ThumbnailCell(
                                        asset: asset,
                                        side: side,
                                        isSelected: selected.contains(asset.localIdentifier),
                                        isTaken: store.containsAsset(asset.localIdentifier),
                                        manager: imageManager
                                    ) { toggle(asset.localIdentifier) }
                                }
                            }
                        } header: {
                            Text(LibrarySections.title(section.dayKey))
                                .font(Face.caption)
                                .foregroundStyle(Tone.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Tone.pure)
                        }
                    }
                    // 오래된 쪽은 아직 읽는 중 — 먼저 모인 최근 하루부터 보인다.
                    if let progress {
                        HStack(spacing: 8) {
                            ProgressView().tint(Tone.tertiary).controlSize(.small)
                            progressLine(progress)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func load() async {
        let s = await LibraryImporter.requestAccess()
        status = s
        guard s == .authorized || s == .limited else { return }
        fetchAssets()
    }

    private func fetchAssets() {
        loading?.cancel()
        loading = Task { @MainActor in
            for await update in Self.loadLibrary() {
                guard !Task.isCancelled else { return }
                library = Library(result: update.result, sections: update.sections)
                progress = update.done < update.total ? LoadProgress(done: update.done, total: update.total) : nil
                // 제한 접근 재선택 뒤 사라진 사진은 selected 에서도 지운다
                if let ids = update.ids { selected = selected.intersection(ids) }
            }
        }
    }

    private static let piece = 300
    private static let partialInterval: CFAbsoluteTime = 0.25

    /// 가져오기·날짜 읽기는 메인 밖에서 조금씩 — 최근 일주일이 모이면 먼저, 그 뒤엔 0.25초마다 보낸다.
    private static func loadLibrary() -> AsyncStream<LoadUpdate> {
        let piece = Self.piece, partialInterval = Self.partialInterval
        return AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let result = PHAsset.fetchAssets(with: LibraryImporter.fetchOptions())
                let total = result.count
                var builder = LibrarySectionBuilder()
                var ids = Set<String>()
                ids.reserveCapacity(total)
                let weekAgo = Date().addingTimeInterval(-7 * 86_400)
                var sentWeek = false
                var lastSent = CFAbsoluteTimeGetCurrent()
                var start = 0
                while start < total {
                    guard !Task.isCancelled else { continuation.finish(); return }
                    let end = min(start + piece, total)
                    var reachedOld = false
                    result.enumerateObjects(at: IndexSet(integersIn: start..<end), options: []) { asset, _, _ in
                        let date = asset.creationDate
                        builder.append(date)
                        ids.insert(asset.localIdentifier)
                        if let date, date < weekAgo { reachedOld = true }
                    }
                    start = end
                    let now = CFAbsoluteTimeGetCurrent()
                    guard start < total, (reachedOld && !sentWeek) || now - lastSent > partialInterval else { continue }
                    sentWeek = sentWeek || reachedOld
                    lastSent = now
                    continuation.yield(LoadUpdate(result: result, sections: builder.sections(complete: false),
                                                  done: start, total: total, ids: nil))
                }
                continuation.yield(LoadUpdate(result: result, sections: builder.sections(complete: true),
                                              done: total, total: total, ids: ids))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func presentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top) { _ in
            Task { @MainActor in fetchAssets() }
        }
    }

    private func importSelected() async {
        isImporting = true
        // 사진첩 전체를 메인에서 훑지 않고 고른 것만 가져온다 — 순서는 예전처럼 최신순.
        let ids = Array(selected)
        let toImport: [PHAsset] = await Task.detached(priority: .userInitiated) {
            var picked: [PHAsset] = []
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: LibraryImporter.fetchOptions())
                .enumerateObjects { asset, _, _ in picked.append(asset) }
            return picked.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }.value
        let importedDayKeys = await LibraryImporter().importAssets(toImport, into: store)
        isImporting = false
        onDone(importedDayKeys)
        dismiss()
    }
}

private struct ThumbnailCell: View {
    let asset: PHAsset
    let side: CGFloat
    let isSelected: Bool
    let isTaken: Bool
    let manager: PHCachingImageManager
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Tone.hairline.opacity(0.3)
                }
            }
            .frame(width: side, height: side)
            .clipped()

            if !isTaken { selectionMark.padding(6) }
        }
        .frame(width: side, height: side)
        .opacity(isTaken ? 0.35 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if !isTaken { onTap() } }
        .task(id: asset.localIdentifier) { await loadImage() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isTaken ? [] : (isSelected ? [.isButton, .isSelected] : .isButton))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 a h:mm"
        return f
    }()

    private var accessibilityLabel: String {
        let time = Self.timeFormatter.string(from: asset.creationDate ?? Date())
        return isTaken ? "\(time), 이미 담았어요" : time
    }

    private var selectionMark: some View {
        ZStack {
            Circle().fill(isSelected ? .white : .black.opacity(0.25))
            if !isSelected { Circle().strokeBorder(.white, lineWidth: 1.5) }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 22, height: 22)
    }

    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat // fastFormat 은 콜백 1회 — opportunistic 이면 두 번 불려 continuation 이 죽는다
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: side * displayScale, height: side * displayScale)
        let request = ThumbnailRequest(manager: manager)
        let result: UIImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                request.start(continuation) {
                    manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill,
                                         options: options) { img, _ in request.finish(img) }
                }
            }
        } onCancel: {
            // 화면 밖으로 스크롤된 칸은 디코딩을 멈춘다 — 보이는 칸만 부른다.
            request.cancel()
        }
        guard !Task.isCancelled else { return }
        if let result { image = result }
    }
}

/// 썸네일 요청 한 건 — 콜백이 두 번 와도, 취소가 먼저 와도 continuation 은 한 번만 푼다.
private final class ThumbnailRequest: @unchecked Sendable {
    private let lock = NSLock()
    private let manager: PHImageManager
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var id: PHImageRequestID?
    private var cancelled = false

    init(manager: PHImageManager) { self.manager = manager }

    func start(_ c: CheckedContinuation<UIImage?, Never>, request: () -> PHImageRequestID) {
        lock.lock()
        guard !cancelled else { lock.unlock(); c.resume(returning: nil); return }
        continuation = c
        lock.unlock()
        let requestID = request()
        lock.lock()
        id = requestID
        let lateCancel = cancelled
        lock.unlock()
        if lateCancel { manager.cancelImageRequest(requestID) }
    }

    func finish(_ image: UIImage?) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(returning: image)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let requestID = id
        lock.unlock()
        if let requestID { manager.cancelImageRequest(requestID) }
        finish(nil)
    }
}
