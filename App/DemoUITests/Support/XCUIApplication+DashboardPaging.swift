import XCTest

@MainActor
extension XCUIApplication {
    func revealDashboardCard(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let pager = descendants(matching: .any).matching(identifier: "dashboard.cards").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 10), file: file, line: line)
        let target = descendants(matching: .any).matching(identifier: identifier).firstMatch
        for _ in 0 ..< 12 {
            if target.exists, pager.frame.contains(target.frame), target.isHittable { return }
            let previous = pager.value as? String ?? ""
            let movesUp = !target.exists || target.frame.midY > pager.frame.midY
            let start = pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movesUp ? 0.8 : 0.2))
            let end = pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movesUp ? 0.2 : 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != %@", previous), object: pager
            )
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, file: file, line: line)
        }
        XCTFail("Dashboard card did not become visible: \(identifier)", file: file, line: line)
    }
}
