import XCTest
@testable import Auth

final class AuthTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Auth().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
