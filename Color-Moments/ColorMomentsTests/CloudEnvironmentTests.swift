import XCTest
@testable import ColorMoments

final class CloudEnvironmentTests: XCTestCase {

    func testProvisioningProfileMeansDevelopment() {
        XCTAssertEqual(CloudEnvironment.detect(hasProvisioningProfile: true, isSimulator: false), .development)
    }

    func testNoProfileOnDeviceMeansProduction() {
        XCTAssertEqual(CloudEnvironment.detect(hasProvisioningProfile: false, isSimulator: false), .production)
    }

    func testSimulatorIsDevelopment() {
        XCTAssertEqual(CloudEnvironment.detect(hasProvisioningProfile: false, isSimulator: true), .development)
        XCTAssertEqual(CloudEnvironment.detect(hasProvisioningProfile: true, isSimulator: true), .development)
    }

    func testSameEnvironmentKeepsState() {
        XCTAssertEqual(CloudEnvironment.decide(saved: .production, current: .production, hasState: true), .keep)
        XCTAssertEqual(CloudEnvironment.decide(saved: .development, current: .development, hasState: false), .keep)
    }

    func testChangedEnvironmentResets() {
        XCTAssertEqual(CloudEnvironment.decide(saved: .development, current: .production, hasState: true), .reset)
        XCTAssertEqual(CloudEnvironment.decide(saved: .production, current: .development, hasState: true), .reset)
        XCTAssertEqual(CloudEnvironment.decide(saved: .development, current: .production, hasState: false), .reset)
    }

    func testUnknownEnvironmentWithStateResetsOnce() {
        XCTAssertEqual(CloudEnvironment.decide(saved: nil, current: .production, hasState: true), .reset)
    }

    func testFreshInstallOnlyRecords() {
        XCTAssertEqual(CloudEnvironment.decide(saved: nil, current: .production, hasState: false), .record)
    }
}
