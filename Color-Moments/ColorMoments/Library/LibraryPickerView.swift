import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LibraryPickerView: View {
    let store: DayStore
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var status: PHAuthorizationStatus?
    @State private var assets: [PHAsset] = []
    @State private var selected: Set<String> = []
    @State private var isImporting = false

    private let imageManager = PHCachingImageManager()
    private static let gridSpacing: CGFloat = 2

    private var sections: [LibrarySection] {
        LibrarySections.make(dates: assets.map(\.creationDate))
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
    }

    @ViewBuilder
    private var content: some View {
        if status == .authorized || status == .limited {
            if status == .limited { limitedBanner }
            grid
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
                                    let asset = assets[i]
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
        var arr: [PHAsset] = []
        arr.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in arr.append(asset) }
        assets = arr
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
        let toImport = assets.filter { selected.contains($0.localIdentifier) }
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
