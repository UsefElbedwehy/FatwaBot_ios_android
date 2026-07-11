import XCTest
import CoreKit
@testable import OnboardingFeature

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private func store() -> OnboardingCompletionStore {
        OnboardingCompletionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private final class Spy: @unchecked Sendable {
        var locationRequested = false
        var notificationsRequested = false
        var finished = false
    }

    private func makeViewModel(spy: Spy, store: OnboardingCompletionStore) -> OnboardingViewModel {
        OnboardingViewModel(
            requestLocation: { spy.locationRequested = true },
            requestNotifications: { spy.notificationsRequested = true },
            completionStore: store,
            onFinished: { spy.finished = true }
        )
    }

    func testStartsAtWelcome() {
        let spy = Spy()
        let viewModel = makeViewModel(spy: spy, store: store())
        XCTAssertEqual(viewModel.step, .welcome)
    }

    func testAdvanceWalksThroughAllFourSteps() {
        let spy = Spy()
        let viewModel = makeViewModel(spy: spy, store: store())

        viewModel.advance()
        XCTAssertEqual(viewModel.step, .highlights)
        viewModel.advance()
        XCTAssertEqual(viewModel.step, .locationPriming)
        viewModel.advance()
        XCTAssertEqual(viewModel.step, .notificationPriming)
    }

    func testSkippingFromTheLastStepFinishesWithoutRequestingAnyPermission() {
        let spy = Spy()
        let s = store()
        let viewModel = makeViewModel(spy: spy, store: s)
        viewModel.advance()
        viewModel.advance()
        viewModel.advance() // now at .notificationPriming

        viewModel.skip()

        XCTAssertTrue(spy.finished)
        XCTAssertFalse(spy.locationRequested)
        XCTAssertFalse(spy.notificationsRequested)
        XCTAssertTrue(s.isCompleted())
    }

    func testAllowLocationRequestsThenAdvancesToNotificationPriming() async {
        let spy = Spy()
        let viewModel = makeViewModel(spy: spy, store: store())
        viewModel.advance() // highlights
        viewModel.advance() // locationPriming

        await viewModel.allowLocation()

        XCTAssertTrue(spy.locationRequested)
        XCTAssertEqual(viewModel.step, .notificationPriming)
        XCTAssertFalse(spy.finished, "location step must not finish onboarding")
    }

    func testAllowNotificationsRequestsThenFinishesOnboarding() async {
        let spy = Spy()
        let s = store()
        let viewModel = makeViewModel(spy: spy, store: s)
        viewModel.advance()
        viewModel.advance()
        viewModel.advance() // notificationPriming

        await viewModel.allowNotifications()

        XCTAssertTrue(spy.notificationsRequested)
        XCTAssertTrue(spy.finished)
        XCTAssertTrue(s.isCompleted())
    }

    func testDecliningLocationStillReachesNotificationPriming() {
        let spy = Spy()
        let viewModel = makeViewModel(spy: spy, store: store())
        viewModel.advance()
        viewModel.advance() // locationPriming

        viewModel.skip()

        XCTAssertFalse(spy.locationRequested, "declining must never call the permission API")
        XCTAssertEqual(viewModel.step, .notificationPriming, "must not be a dead end")
    }
}
