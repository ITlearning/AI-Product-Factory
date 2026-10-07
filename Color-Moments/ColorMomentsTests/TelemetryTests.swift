import Photos
import PostHog
import XCTest
@testable import ColorMoments

final class TelemetryTests: XCTestCase {

    func testSendsOnlyWithKeyAndSwitchOnOutsideTests() {
        XCTAssertFalse(Telemetry.sends(apiKey: "", enabled: true, testing: false))
        XCTAssertFalse(Telemetry.sends(apiKey: "phc_ABC", enabled: false, testing: false))
        XCTAssertFalse(Telemetry.sends(apiKey: "phc_ABC", enabled: true, testing: true))
        XCTAssertTrue(Telemetry.sends(apiKey: "phc_ABC", enabled: true, testing: false))
    }

    func testConfigGoesToEUAndCapturesNothingOnItsOwn() {
        let config = Telemetry.makeConfig(apiKey: "phc_ABC")
        XCTAssertEqual(config.projectToken, "phc_ABC")
        XCTAssertEqual(config.host.absoluteString, "https://eu.i.posthog.com")
        XCTAssertFalse(config.enableSwizzling)
        XCTAssertFalse(config.sessionReplay)
        XCTAssertFalse(config.captureScreenViews)
        XCTAssertFalse(config.captureElementInteractions)
        XCTAssertFalse(config.captureSwiftUIElementInteractions)
        XCTAssertFalse(config.captureAutocaptureElementText)
        XCTAssertFalse(config.rageClickConfig.enabled)
        XCTAssertFalse(config.capturePushNotificationSubscriptions)
        XCTAssertFalse(config.capturePushNotificationOpened)
        XCTAssertFalse(config.surveys)
        XCTAssertFalse(config.preloadFeatureFlags)
        XCTAssertFalse(config.sendFeatureFlagEvent)
        XCTAssertFalse(config.errorTrackingConfig.autoCapture)
        XCTAssertEqual(config.personProfiles, .never)
        XCTAssertFalse(config.setDefaultPersonProperties)
        XCTAssertTrue(config.disableGeoIp)
        XCTAssertNil(config.tracingHeaders)
        XCTAssertFalse(config.optOut)
    }

    func testSendDoesNothingWhileTesting() {
        Telemetry.apply()
        Telemetry.send(.wordRejected)
        XCTAssertTrue(PostHogSDK.shared.isOptOut())
    }

    func testSwitchDefaultsOn() {
        let key = Telemetry.enabledKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(Telemetry.isEnabled)
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(Telemetry.isEnabled)
    }

    private static let allSteps: [OnboardingStep] = [.intro, .firstPebble, .continuing, .place, .arrival, .reminder,
                                                     .cloud, .howTo, .cameraButton, .collection, .start]

    private static var allEvents: [Telemetry.Event] {
        var events: [Telemetry.Event] = allSteps.map { .onboardingStep($0) }
        events += Telemetry.Exit.allCases.map { .onboardingFinished($0) }
        for a in Telemetry.Answer.allCases { events += [.photoAccess(a), .placeAccess(a), .noticeAccess(a)] }
        for s in Telemetry.Source.allCases { events += [.firstPhoto(s), .photoAdded(s, count: 3)] }
        events += Telemetry.Place.allCases.map { .firstPebble($0) }
        events += Telemetry.CameraPath.allCases.map { .cameraOpened($0) }
        events.append(.wordRejected)
        return events
    }

    /// 보낼 수 있는 값은 미리 정한 집합뿐 — 사진·단어·날짜 같은 자유 문자열이 섞일 자리가 없다.
    func testParametersOnlyCarryFixedValues() {
        let allowed: [String: Set<String>] = [
            "step": Set(Telemetry.stepNames),
            "exit": Set(Telemetry.Exit.allCases.map(\.rawValue)),
            "answer": Set(Telemetry.Answer.allCases.map(\.rawValue)),
            "source": Set(Telemetry.Source.allCases.map(\.rawValue)),
            "where": Set(Telemetry.Place.allCases.map(\.rawValue)),
            "path": Set(Telemetry.CameraPath.allCases.map(\.rawValue)),
        ]
        for event in Self.allEvents {
            XCTAssertLessThanOrEqual(event.parameters.count, 1, event.name)
            for (key, value) in event.parameters {
                XCTAssertTrue(allowed[key]?.contains(value) ?? false, "\(event.name) \(key)=\(value)")
            }
        }
    }

    func testEveryStepHasItsOwnName() {
        let names = Self.allSteps.map(Telemetry.stepName)
        XCTAssertEqual(Set(names).count, Self.allSteps.count)
        XCTAssertEqual(Set(names), Set(Telemetry.stepNames))
    }

    /// 「묶음.동작」 한 가지 꼴 — PostHog 의 `$` 이벤트나 앱 수명주기 이벤트(「Application Opened」)와 겹치지 않는다.
    func testEventNamesAreFixedAndConsistent() {
        let names = Set(Self.allEvents.map(\.name))
        XCTAssertEqual(names.count, 10)
        for name in names {
            let parts = name.split(separator: ".")
            XCTAssertEqual(parts.count, 2, name)
            XCTAssertTrue(parts.allSatisfy { $0.first?.isLetter == true && $0.allSatisfy(\.isLetter) }, name)
            XCTAssertTrue(parts[0].first?.isUppercase == true, name)
            XCTAssertTrue(parts[1].first?.isLowercase == true, name)
        }
    }

    func testOnlyPhotoAddedCarriesWholeCount() {
        let added = Telemetry.Event.photoAdded(.library, count: 12).properties
        XCTAssertEqual(added["count"] as? Int, 12)
        XCTAssertEqual(added["source"] as? String, "library")
        XCTAssertEqual(added.count, 2)
        XCTAssertNil(Telemetry.Event.firstPhoto(.app).count)
        XCTAssertNil(Telemetry.Event.cameraOpened(.swipe).properties["count"])
        for event in Self.allEvents where event.count == nil {
            XCTAssertEqual(event.properties.count, event.parameters.count, event.name)
        }
    }

    func testExitDropsDayKey() {
        XCTAssertEqual(Telemetry.Event.onboardingFinished(Telemetry.Exit(.day("2026-10-07"))).parameters, ["exit": "day"])
    }

    func testFirstPhotoOnlyWhenRecordsWereEmpty() {
        XCTAssertTrue(Telemetry.isFirstPhoto(count: 1, total: 1, alreadyMarked: false))
        XCTAssertTrue(Telemetry.isFirstPhoto(count: 5, total: 5, alreadyMarked: false))
        XCTAssertFalse(Telemetry.isFirstPhoto(count: 1, total: 40, alreadyMarked: false))
        XCTAssertFalse(Telemetry.isFirstPhoto(count: 1, total: 1, alreadyMarked: true))
        XCTAssertFalse(Telemetry.isFirstPhoto(count: 0, total: 0, alreadyMarked: false))
    }

    func testFirstPebbleOnlyForFreshStarts() {
        XCTAssertTrue(Telemetry.isFirstPebble(startedFresh: true, alreadyMarked: false))
        XCTAssertFalse(Telemetry.isFirstPebble(startedFresh: false, alreadyMarked: false))
        XCTAssertFalse(Telemetry.isFirstPebble(startedFresh: true, alreadyMarked: true))
    }

    func testFirstMarksAreSetOnceEvenWithoutSending() {
        let defaults = UserDefaults(suiteName: "TelemetryTests")!
        defaults.removePersistentDomain(forName: "TelemetryTests")
        defer { defaults.removePersistentDomain(forName: "TelemetryTests") }
        Telemetry.pebbleReceived(.home, defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: Telemetry.firstPebbleKey))
        Telemetry.photosAdded(.app, count: 1, total: 1, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: Telemetry.firstPhotoKey))
        Telemetry.pebbleReceived(.onboarding, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: Telemetry.firstPebbleKey))
    }

    func testPhotoAccessMapping() {
        XCTAssertEqual(Telemetry.Answer(.authorized), .allowed)
        XCTAssertEqual(Telemetry.Answer(.limited), .limited)
        XCTAssertEqual(Telemetry.Answer(.denied), .denied)
        XCTAssertEqual(Telemetry.Answer(.restricted), .denied)
    }
}
