import XCTest

@testable import GotoNativeCore

final class FinderErrorPresenterTests: XCTestCase {
    func testSelectionErrorMessagesAreConcrete() {
        let presenter = FinderErrorPresenter()

        XCTAssertEqual(
            presenter.present(selectionError: .emptySelection),
            UserFacingError(
                title: "No Folder Selected",
                message: "Select one folder in Finder, then try goto again."
            )
        )

        XCTAssertEqual(
            presenter.present(selectionError: .multipleSelections(count: 3)),
            UserFacingError(
                title: "Select One Folder",
                message: "goto can open one folder at a time. You selected 3 items."
            )
        )
    }

    func testLaunchErrorMessagesCoverPermissionAndGenericFailure() {
        let presenter = FinderErrorPresenter()

        XCTAssertEqual(
            presenter.present(launchError: .permissionDenied),
            UserFacingError(
                title: "Terminal Permission Required",
                message: "Allow goto to control Terminal in System Settings, then try again."
            )
        )

        XCTAssertEqual(
            presenter.present(launchError: .launchFailed(reason: "bad script")),
            UserFacingError(
                title: "Could Not Open Terminal",
                message: "bad script"
            )
        )
    }
}
