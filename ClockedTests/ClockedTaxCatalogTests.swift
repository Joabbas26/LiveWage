//
//  ClockedTaxCatalogTests.swift
//  ClockedTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import Clocked

final class ClockedTaxCatalogTests: XCTestCase {
    func testMissingBundleFallsBackWithoutCrashing() {
        let catalog = ClockedTaxCatalog(bundle: Bundle(for: Self.self))

        XCTAssertNotNil(catalog.loadingIssue)
        XCTAssertFalse(catalog.availableLocations.isEmpty)

        let profile = catalog.profile(for: .texas)
        XCTAssertEqual(profile.stateRule.strategy, .none)
        XCTAssertNil(profile.localRule)
        XCTAssertEqual(profile.taxLabel, "Federal + FICA estimate")
        XCTAssertTrue(profile.assumptionLabel.contains("federal income tax and FICA only"))
    }

    func testUnknownLocationGetsSafePlaceholderProfile() {
        let catalog = ClockedTaxCatalog(table: .fallbackBaseline())
        let location = LocationOption(rawValue: "unknownPlace")
        let profile = catalog.profile(for: location)

        XCTAssertEqual(profile.displayName, "Unknown Place")
        XCTAssertEqual(profile.shortName, "UP")
        XCTAssertEqual(profile.stateRule.strategy, .none)
        XCTAssertNil(profile.localRule)
    }
}
