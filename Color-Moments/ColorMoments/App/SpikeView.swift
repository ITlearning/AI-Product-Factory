import SwiftUI

/// Gate: LockedCameraCapture 스파이크 확인 화면.
///
/// 확인할 것 넷:
/// 1) 잠금화면에서 확장이 뜨는가
/// 2) 잠긴 상태로 찍히는가
/// 3) sessionContentUpdates 로 본 앱에 넘어오는가
/// 4) 원본 무효화가 되는가 (안 되면 같은 사진을 반복해서 받는다)
///
/// **이 화면은 제품 UI가 아니라 계측기다.** 제품 진입점은 `HomeView` 로 넘어갔고(2026-09-22),
/// 여기는 DEBUG 빌드에서 홈의 공구 아이콘 뒤에만 남아 있다. 버리지 않고 물린 이유는
/// 잠금화면 수신 로그가 사진첩 B 경로 작업에 아직 필요해서다. B 가 끝나면 지운다.
///
/// **증정은 여기서 띄우지 않는다.** 홈이 `.dayGift` 로 띄우는데 여기서도 띄우면 두 번 뜬다.
struct SpikeView: View {
    @Bindable var inbox: CaptureInbox
    @Bindable var store: DayStore
    private let gifts: GiftLog
    @State private var camera: CaptureEngine
    @State private var confirmingWipe = false
    /// 미리 보기 중인가. **이력에 남기지 않는다** — 여기서 남기면 진짜 증정이 영영 안 온다.
    @State private var previewing = false

    init(inbox: CaptureInbox, store: DayStore, gifts: GiftLog) {
        self.inbox = inbox
        self.store = store
        self.gifts = gifts
        _camera = State(initialValue: CaptureEngine(
            destination: { ShotStore.directory },
            onRecorded: { store.add($0) }
        ))
    }

    var body: some View {
        NavigationStack {
            List {
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
                            // 자정에 증정될 그라데이션. 시간 간격이 반영돼 있다.
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
                            // 비교용 — 각 순간의 색을 균등 폭으로. 렌더러 검증에만 쓰고 제품엔 안 나간다.
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
                        BadgeRowView(store: store)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        Text("격자가 아니라 줄이다. 안 담은 날은 조약돌이 없을 뿐 구멍이 아니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

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
            .navigationTitle("Gate · 잠금화면 촬영")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $previewing) {
                BadgeCeremony(moments: store.today, isPresented: $previewing)
            }
            .confirmationDialog("전부 지울까요?", isPresented: $confirmingWipe, titleVisibility: .visible) {
                Button("지우기", role: .destructive) {
                    store.removeAll()
                    inbox.reset()
                    // 증정 커서만 남으면 아무것도 증정되지 않는다.
                    gifts.reset()
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
}
