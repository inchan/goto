import XCTest
@testable import GotoNativeCore

final class LaunchDebouncerTests: XCTestCase {
    func testDebouncerAllowsFirstLaunch() {
        var debouncer = LaunchDebouncer(minimumInterval: 1.0)
        let instant = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertTrue(debouncer.shouldLaunch(path: "/tmp/demo", at: instant))
    }

    func testDebouncerBlocksDuplicateLaunchWithinInterval() {
        var debouncer = LaunchDebouncer(minimumInterval: 1.0)
        let first = Date(timeIntervalSinceReferenceDate: 1_000)
        let second = Date(timeIntervalSinceReferenceDate: 1_000.5)

        XCTAssertTrue(debouncer.shouldLaunch(path: "/tmp/demo", at: first))
        XCTAssertFalse(debouncer.shouldLaunch(path: "/tmp/demo", at: second))
    }

    func testDebouncerAllowsDifferentPathImmediately() {
        var debouncer = LaunchDebouncer(minimumInterval: 1.0)
        let first = Date(timeIntervalSinceReferenceDate: 1_000)
        let second = Date(timeIntervalSinceReferenceDate: 1_000.1)

        XCTAssertTrue(debouncer.shouldLaunch(path: "/tmp/demo", at: first))
        XCTAssertTrue(debouncer.shouldLaunch(path: "/tmp/other", at: second))
    }
}
