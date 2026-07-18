import XCTest
@testable import CoreKit

final class OnboardingCompletionStoreTests: XCTestCase {
    private func makeStore() -> OnboardingCompletionStore {
        OnboardingCompletionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    func testIsCompletedIsFalseUntilMarked() {
        let store = makeStore()
        XCTAssertFalse(store.isCompleted())
    }

    func testMarkCompletedPersists() {
        let store = makeStore()
        store.markCompleted()
        XCTAssertTrue(store.isCompleted())
    }

    func testCompletionSurvivesAFreshStoreInstanceOverTheSameDirectory() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        OnboardingCompletionStore(directory: directory).markCompleted()
        XCTAssertTrue(OnboardingCompletionStore(directory: directory).isCompleted())
    }
}
