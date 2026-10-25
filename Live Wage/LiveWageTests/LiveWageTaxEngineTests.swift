//
//  LiveWageTaxEngineTests.swift
//  LiveWageTests
//
//  Created by Codex on 5/5/26.
//

import XCTest
@testable import LiveWage

final class LiveWageTaxEngineTests: XCTestCase {
    func testEstimateMatchesSimpleTexasBaseline() {
        let configuration = EarningsConfiguration(
            salaryAmount: 100_000,
            payFrequency: .annual,
            filingStatus: .single,
            location: .texas,
            workHoursPerDay: 8,
            workDaysPerWeek: 5,
            workStartMinutes: 9 * 60,
            annualBonusAmount: 0,
            monthlyPretaxBenefitsAmount: 0,
            retirementContributionPercent: 0,
            savingsGoalAmount: 5_000
        )

        let estimate = LiveWageTaxEngine.estimate(for: configuration)

        XCTAssertEqual(estimate.taxableFederalIncome, 84_250, accuracy: 0.01)
        XCTAssertEqual(estimate.federalIncomeTax, 13_449, accuracy: 0.01)
        XCTAssertEqual(estimate.socialSecurityTax, 6_200, accuracy: 0.01)
        XCTAssertEqual(estimate.medicareTax, 1_450, accuracy: 0.01)
        XCTAssertEqual(estimate.stateIncomeTax, 0, accuracy: 0.01)
        XCTAssertEqual(estimate.localIncomeTax, 0, accuracy: 0.01)
        XCTAssertEqual(estimate.annualNet, 78_901, accuracy: 0.01)
        XCTAssertEqual(estimate.netPerSecond, 0.01053699, accuracy: 0.0000001)
    }

    func testEstimateCapsRetirementContributionAtAnnualLimit() {
        var configuration = EarningsConfiguration.default
        configuration.salaryAmount = 500_000
        configuration.location = .texas
        configuration.retirementContributionPercent = 10

        let estimate = LiveWageTaxEngine.estimate(for: configuration)

        XCTAssertEqual(
            estimate.annualRetirementContribution,
            EarningsConfiguration.retirementDeferralLimit,
            accuracy: 0.01
        )
    }
}
