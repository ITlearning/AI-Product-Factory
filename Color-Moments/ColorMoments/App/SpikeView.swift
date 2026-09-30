import SwiftUI

struct SpikeView: View {
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @State private var showingEmptyHome = false
    #endif
    @Bindable var inbox: CaptureInbox
    @Bindable var store: DayStore
    private let gifts: GiftLog
    private let closures: DayClosures
    @State private var camera: CaptureEngine
    @State private var confirmingWipe = false

    @State private var previewing = false
    #if DEBUG
    @State private var diagnostics: AssetDiagnostics.Snapshot?
    @State private var diagnosing = false
    @State private var confirmingRestore = false
    @State private var restoreResult: String?
    #endif

    init(inbox: CaptureInbox, store: DayStore, gifts: GiftLog, closures: DayClosures) {
        self.inbox = inbox
        self.store = store
        self.gifts = gifts
        self.closures = closures
        _camera = State(initialValue: CaptureEngine(
            destination: { ShotStore.directory },
            onRecorded: { store.add($0) }
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                Section {
                    NavigationLink("조약돌 비교 (셰이더)") { PebbleLabView(store: store, gifts: gifts, closures: closures) }
                }
                #endif
                Section("앱 촬영 (A 경로)") {
                    CaptureScreen(engine: camera)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(EdgeInsets())
                    if let shot = camera.lastShot {
                        HStack(spacing: 12) {
                            Image(uiImage: shot.image).resizable().scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: shot.color.r, green: shot.color.g, blue: shot.color.b))
                                .frame(width: 52, height: 52)
                            Text(shot.color.hex).font(.caption.monospaced())
                        }
                    }
                    if camera.permissionDenied {
                        Text("카메라 권한이 꺼져 있습니다.").font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("오늘 \(store.today.count)개 · \(Moment.dayKey(for: Date()))") {
                    if store.today.isEmpty {
                        Text("아직 없음").foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 6) {

                            DayGradientView(moments: store.today)
                                .frame(height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            if let span = DayGradient.span(for: store.today) {
                                HStack {
                                    Text(DayGradient.timeText(span.from))
                                    Spacer()
                                    Text("\(store.today.count)개")
                                    Spacer()
                                    Text(DayGradient.timeText(span.to))
                                }
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 0) {
                                ForEach(store.today) { m in
                                    Rectangle().fill(Color(hex: m.colorHex)).frame(height: 14)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .opacity(0.65)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    ForEach(store.today) { m in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 5).fill(Color(hex: m.colorHex))
                                .frame(width: 26, height: 26)
                            Text(m.colorHex).font(.caption.monospaced())
                            Spacer()
                            Text(m.source == .locked ? "잠금화면" : "앱")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(m.capturedAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }

                if !store.today.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            DayBadgeView(moments: store.today, size: 120, showsCaption: false)
                            if let named = PebbleNaming.name(for: store.today) {
                                VStack(spacing: 2) {
                                    Text(named.name)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    Text(named.line)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    } header: {
                        Text("오늘의 조약돌")
                    } footer: {
                        Text("자정에 이 조약돌이 증정됩니다.")
                    }

                    Section {
                        Button {
                            previewing = true
                        } label: {
                            Label("증정 미리 보기", systemImage: "sparkles")
                        }
                    } footer: {
                        Text("""
                        자정에 나올 장면입니다. 미리 보기는 이력에 남지 않아 진짜 증정을 잡아먹지 않습니다.
                        마지막 증정: \(gifts.lastGiftedDayKey ?? "없음")
                        """)
                    }

                    Section("모으면 이렇게") {
                        BadgeRowView(store: store, closures: closures)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        Text("격자가 아니라 줄이다. 안 담은 날은 조약돌이 없을 뿐 구멍이 아니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                assetDiagnosticsSection

                Section {
                    Button {
                        UserDefaults.standard.set(true, forKey: "debugReplayOnboarding")
                        dismiss()
                    } label: {
                        Label("온보딩 다시 보기", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        showingEmptyHome = true
                    } label: {
                        Label("빈 홈 미리 보기", systemImage: "square.dashed")
                    }
                } footer: {
                    Text("기록은 그대로 두고 첫 화면부터 다시 봅니다. 권한 창은 이미 답했으면 다시 뜨지 않아요. 빈 홈은 실제 기록과 떨어진 빈 저장소로 그립니다.")
                }
                #endif

                Section {
                    Button(role: .destructive) { confirmingWipe = true } label: {
                        Label("전부 지우기", systemImage: "trash")
                    }
                    .disabled(store.moments.isEmpty && inbox.imported.isEmpty)
                } footer: {
                    Text("기록 \(store.moments.count)개와 사진 파일을 모두 지웁니다. 되돌릴 수 없어요.")
                }

                Section("확인 절차") {
                    step(1, "설정 > 카메라 > 카메라 컨트롤 에서 「몽돌」 선택")
                    step(2, "화면 잠그고 카메라 컨트롤 버튼 누르기")
                    step(3, "잠긴 채로 사진 찍기")
                    step(4, "잠금 풀고 이 앱 열기 → 아래 목록에 뜨면 통과")
                }

                Section("들여온 사진 \(inbox.imported.count)") {
                    if inbox.imported.isEmpty {
                        Text("아직 없음").foregroundStyle(.secondary)
                    }
                    ForEach(inbox.imported) { item in
                        HStack(spacing: 12) {
                            if let img = UIImage(contentsOfFile: item.url.path) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .font(.caption.monospaced())
                                Text("\(item.byteCount / 1024)KB · \(item.importedAt.formatted(date: .omitted, time: .standard))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("수신 로그") {
                    if inbox.log.isEmpty {
                        Text("아직 없음").foregroundStyle(.secondary)
                    }
                    ForEach(inbox.log, id: \.self) { line in
                        Text(line).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            #if DEBUG
            .task { await refreshDiagnostics() }
            #endif
            .onAppear { inbox.loadExisting() }
            .navigationTitle("Gate · 잠금화면 촬영")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $previewing) {
                BadgeCeremony(moments: store.today, isPresented: $previewing)
            }
            #if DEBUG
            // Form 안 Section 에 붙이면 행이 다시 그려질 때 커버가 바로 닫힌다 — 바깥에 둔다.
            .fullScreenCover(isPresented: $showingEmptyHome) { EmptyHomePreview() }
            #endif
            .confirmationDialog("전부 지울까요?", isPresented: $confirmingWipe, titleVisibility: .visible) {
                Button("지우기", role: .destructive) {
                    store.removeAll()
                    inbox.reset()

                    gifts.reset()
                    closures.reset()
                    HomeWidget.refresh(store: store, gifts: gifts)
                    Task { await ArrivalNotice.removeAll() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기록 \(store.moments.count)개와 사진 파일이 모두 사라집니다. 되돌릴 수 없어요.")
            }

        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)").font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 18, height: 18)
                .background(.tint.opacity(0.15), in: Circle())
            Text(text).font(.subheadline)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var assetDiagnosticsSection: some View {
        Section {
            if let d = diagnostics {
                let c = d.counts
                row("권한", AssetDiagnostics.statusText(d.status))
                row("loadIssue", d.loadIssue.map { "\($0)" } ?? "없음")
                row("isSaveBlocked", d.isSaveBlocked ? "예" : "아니오")
                row("전체 기록", "\(d.total)")
                row("① 파일만·파일 있음", "\(c.fileOnly)")
                row("② 파일만·파일 없음", "\(c.fileOnlyMissing)")
                row("③ 에셋 없음·파일 있음 (library-/그 밖)", "\(c.lostWithLibraryFile) / \(c.lostWithOtherFile)")
                row("④ 에셋 없음·파일 없음", "\(c.lostNoFile)")
                row("⑤ 에셋 있음·cloudID 없음", "\(c.foundNoCloud)")
                row("⑥ cloudID 없음 전체", "\(c.noCloud)")
                row("이번 실행 입양 시도/성공", "\(d.stats.adoptTried)/\(d.stats.adoptSucceeded)")
                row("이번 실행 수동 복구 시도/성공", "\(d.stats.readoptTried)/\(d.stats.readoptSucceeded)")
                Text("마지막 저장 실패: \(d.stats.lastFailure?.summary ?? "없음")")
                    .font(.caption2.monospaced()).textSelection(.enabled)
                if let fallback = d.stats.lastFallback {
                    Text("대안으로 성공: \(fallback.summary)")
                        .font(.caption2.monospaced()).textSelection(.enabled)
                }
                ForEach(c.examples, id: \.self) { line in
                    Text(line).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } else {
                Text("세는 중…").foregroundStyle(.secondary)
            }
            Button {
                Task {
                    diagnosing = true
                    await AssetAdopter.adoptAll(store: store)
                    await refreshDiagnostics()
                    diagnosing = false
                }
            } label: {
                Label(diagnosing ? "옮기는 중…" : "지금 다시 옮기기", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(diagnosing)
            let lostWithFile = diagnostics.map { $0.counts.lostWithLibraryFile + $0.counts.lostWithOtherFile } ?? 0
            Button {
                confirmingRestore = true
            } label: {
                Label("복구(사본을 사진 앱에 다시 저장)", systemImage: "arrow.uturn.backward")
            }
            .disabled(diagnosing || lostWithFile == 0)
            .confirmationDialog("사본을 사진 앱에 다시 저장할까요?", isPresented: $confirmingRestore,
                                titleVisibility: .visible) {
                Button("최대 \(AssetAdopter.restoreLimit)개 다시 저장") {
                    Task {
                        diagnosing = true
                        let n = await AssetAdopter.restoreLost(store: store)
                        restoreResult = "\(n)개 다시 저장함"
                        await refreshDiagnostics()
                        diagnosing = false
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("사진 앱에서 사라진 기록 \(lostWithFile)개 중 최대 \(AssetAdopter.restoreLimit)개를 이 기기에 남은 사본으로 사진 앱에 다시 저장합니다. 사진 앱에서 일부러 지운 사진이면 다시 생겨요.")
            }
            if let restoreResult {
                Text("복구: \(restoreResult)").font(.caption2).foregroundStyle(.secondary)
            }
            Button("다시 세기") { Task { await refreshDiagnostics() } }
        } header: {
            Text("사진 앱 옮기기 진단")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func refreshDiagnostics() async {
        diagnostics = await AssetDiagnostics.snapshot(store: store)
    }
    #endif
}

#if DEBUG
/// 실제 기록·설정과 떨어진 빈 저장소로 홈을 그린다 — 첫날 홈이 어떻게 보이는지 확인용.
private struct EmptyHomePreview: View {
    @Environment(\.dismiss) private var dismiss
    private static let suite = "debug-empty-home"
    @State private var closures = DayClosures(defaults: UserDefaults(suiteName: suite)!)
    @State private var gifts = GiftLog(defaults: UserDefaults(suiteName: suite)!)
    @State private var store: DayStore?
    @State private var focusDay: String?
    @State private var scrubbing = false
    @State private var daySheetPresented = false
    @State private var keepsakePresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let store {
                HomeView(store: store, gifts: gifts, showsSwipeHint: true,
                         focusDay: $focusDay, closures: closures, scrubbing: $scrubbing,
                         daySheetPresented: $daySheetPresented,
                         keepsakePresented: $keepsakePresented)
                    .defaultAppStorage(UserDefaults(suiteName: Self.suite)!)
            }
            Button("닫기") { dismiss() }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.trailing, 20).padding(.top, 60)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UserDefaults(suiteName: Self.suite)!.removePersistentDomain(forName: Self.suite)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("debug-empty-home.json")
            try? FileManager.default.removeItem(at: url)
            store = DayStore(fileURL: url, closures: closures)
        }
    }
}
#endif
