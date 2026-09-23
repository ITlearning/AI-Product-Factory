import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LibraryPickerView: View {
    let store: DayStore
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var status: PHAuthorizationStatus?
    @State private var fetchResult = PHFetchResult<PHAsset>()
    @State private var sections: [LibrarySection] = []
    @State private var selected: Set<String> = []
    @State private var isImporting = false
    @State private var imageManager = PHCachingImageManager()

    private static let gridSpacing: CGFloat = 2

    var body: some View {
        ZStack {
            Tone.pure.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content
            }
        }
        .task { await load() }
        .interactiveDismissDisabled(isImporting)
    }

    @ViewBuilder
    private var content: some View {
        if status == .authorized || status == .limited {
            if status == .limited { limitedBanner }
            grid
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

    private var deniedState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("설정에서 사진 접근을 켜 주세요")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
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

    private var grid: some View {
        GeometryReader { geo in
            let side = (geo.size.width - Self.gridSpacing * 2) / 3
            let columns = Array(repeating: GridItem(.fixed(side), spacing: Self.gridSpacing), count: 3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections, id: \.dayKey) { section in
                        Section {
                            LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                                ForEach(section.indices, id: \.self) { i in
                                    let asset = fetchResult.object(at: i)
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
        let result = PHAsset.fetchAssets(with: LibraryImporter.fetchOptions())
        fetchResult = result
        Task {
            let (computed, ids) = await Self.computeSections(result)
            sections = computed
            selected = selected.intersection(ids) // 제한 접근 재선택 뒤 사라진 사진은 selected 에서도 지운다
        }
    }

    private static func computeSections(_ result: PHFetchResult<PHAsset>) async -> ([LibrarySection], Set<String>) {
        await Task.detached(priority: .userInitiated) {
            var dates: [Date?] = []
            var ids: Set<String> = []
            dates.reserveCapacity(result.count)
            ids.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                dates.append(asset.creationDate)
                ids.insert(asset.localIdentifier)
            }
            return (LibrarySections.make(dates: dates), ids)
        }.value
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
        var toImport: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if selected.contains(asset.localIdentifier) { toImport.append(asset) }
        }
        let n = await LibraryImporter().importAssets(toImport, into: store)
        isImporting = false
        onDone(n)
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
        let result: UIImage? = await withCheckedContinuation { continuation in
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill,
                                  options: options) { img, _ in continuation.resume(returning: img) }
        }
        if let result { image = result }
    }
}
