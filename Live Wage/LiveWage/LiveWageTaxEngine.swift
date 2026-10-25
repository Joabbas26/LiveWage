//
//  LiveWageTaxEngine.swift
//  LiveWage
//
//  Created by Codex on 5/4/26.
//

import Foundation

enum LiveWageTaxEngine {
    private static let catalog = LiveWageTaxCatalog.shared

    static var taxYear: Int {
        catalog.table.taxYear
    }

    static var loadingIssue: LiveWageTaxCatalogLoadIssue? {
        catalog.loadingIssue
    }

    static var availableLocations: [LocationOption] {
        catalog.availableLocations
    }

    static func hasBundledProfile(for location: LocationOption) -> Bool {
        catalog.profileIfAvailable(for: location) != nil
    }

    static func estimate(for configuration: EarningsConfiguration) -> EarningsEstimate {
        let annualBasePay = configuration.annualBaseIncome
        let annualBonus = configuration.annualBonusAmount
        let annualGross = configuration.annualGrossIncome
        let annualPretaxBenefits = configuration.annualPretaxBenefits
        let annualRetirementContribution = configuration.annualRetirementContribution
        let locationProfile = profile(for: configuration.location)

        let federalTaxableIncome = max(
            configuration.annualTaxableWagesForFederal
                - catalog.table.federal.standardDeductions[configuration.filingStatus],
            0
        )
        let federalIncomeTax = tax(
            using: catalog.table.federal.brackets[configuration.filingStatus],
            taxableIncome: federalTaxableIncome
        )

        let socialSecurityTax = min(
            configuration.annualTaxableWagesForFICA,
            catalog.table.fica.socialSecurityWageBase
        ) * catalog.table.fica.socialSecurityRate

        let medicareThreshold = catalog.table.fica.additionalMedicareThresholds[configuration.filingStatus]
        let medicareTax = (configuration.annualTaxableWagesForFICA * catalog.table.fica.medicareRate)
            + (max(configuration.annualTaxableWagesForFICA - medicareThreshold, 0) * catalog.table.fica.additionalMedicareRate)

        let stateIncomeTax = incomeTax(
            using: locationProfile.stateRule,
            configuration: configuration,
            federalTaxableIncome: federalTaxableIncome
        )
        let localIncomeTax = incomeTax(
            using: locationProfile.localRule,
            configuration: configuration,
            federalTaxableIncome: federalTaxableIncome
        )

        let annualNet = max(
            annualGross
                - annualPretaxBenefits
                - annualRetirementContribution
                - federalIncomeTax
                - socialSecurityTax
                - medicareTax
                - stateIncomeTax
                - localIncomeTax,
            0
        )

        let annualWorkSeconds = max(configuration.annualWorkSeconds, 1)
        let workDaysPerYear = max(configuration.workDaysPerYear, 1)

        return EarningsEstimate(
            annualBasePay: annualBasePay,
            annualBonus: annualBonus,
            annualGross: annualGross,
            annualPretaxBenefits: annualPretaxBenefits,
            annualRetirementContribution: annualRetirementContribution,
            annualNet: annualNet,
            grossDaily: annualGross / workDaysPerYear,
            netDaily: annualNet / workDaysPerYear,
            grossPerSecond: annualGross / annualWorkSeconds,
            netPerSecond: annualNet / annualWorkSeconds,
            taxableFederalIncome: federalTaxableIncome,
            federalIncomeTax: federalIncomeTax,
            stateIncomeTax: stateIncomeTax,
            localIncomeTax: localIncomeTax,
            socialSecurityTax: socialSecurityTax,
            medicareTax: medicareTax,
            taxYear: taxYear
        )
    }

    static func assumptionsLabel(for configuration: EarningsConfiguration) -> String {
        profile(for: configuration.location).assumptionLabel
    }

    static func stateTaxTitle(for location: LocationOption) -> String {
        profile(for: location).stateTaxTitle
    }

    static func localTaxTitle(for location: LocationOption) -> String? {
        profile(for: location).localTaxTitle
    }

    static func hasLocalIncomeTax(for location: LocationOption) -> Bool {
        guard let localRule = profile(for: location).localRule else { return false }
        return localRule.strategy != .none
    }

    private static func profile(for location: LocationOption) -> LocationTaxProfile {
        catalog.profile(for: location)
    }

    private static func incomeTax(
        using rule: TaxRule?,
        configuration: EarningsConfiguration,
        federalTaxableIncome: Double
    ) -> Double {
        guard let rule else { return 0 }

        switch rule.strategy {
        case .none:
            return 0
        case .flat:
            let taxableIncome = taxableIncome(
                using: rule,
                configuration: configuration,
                federalTaxableIncome: federalTaxableIncome
            )
            return taxableIncome * (rule.flatRate ?? 0)
        case .progressive:
            return tax(
                using: rule.brackets?[configuration.filingStatus] ?? [],
                taxableIncome: taxableIncome(
                    using: rule,
                    configuration: configuration,
                    federalTaxableIncome: federalTaxableIncome
                )
            )
        case .progressiveWithCredit:
            let taxableIncome = taxableIncome(
                using: rule,
                configuration: configuration,
                federalTaxableIncome: federalTaxableIncome
            )
            let scheduleTax = tax(
                using: rule.brackets?[configuration.filingStatus] ?? [],
                taxableIncome: taxableIncome
            )
            let personalCredit = rule.personalCredits?[configuration.filingStatus] ?? 0
            return max(scheduleTax - personalCredit, 0)
        case .flatWithExemption:
            let compensation = taxableBaseAmount(
                for: rule.taxableBase,
                configuration: configuration,
                federalTaxableIncome: federalTaxableIncome
            )
            let taxableIncome = max(
                compensation - exemptionAllowance(
                    using: rule.exemption,
                    filingStatus: configuration.filingStatus,
                    taxableCompensation: compensation
                ),
                0
            )
            return taxableIncome * (rule.flatRate ?? 0)
        case .flatWithSurtax:
            let taxableIncome = taxableIncome(
                using: rule,
                configuration: configuration,
                federalTaxableIncome: federalTaxableIncome
            )
            let baseTax = taxableIncome * (rule.flatRate ?? 0)
            let surtax = max(taxableIncome - (rule.surtaxThreshold ?? 0), 0) * (rule.surtaxRate ?? 0)
            return baseTax + surtax
        case .newYorkRecapture:
            return newYorkRecaptureTax(
                using: rule,
                configuration: configuration,
                federalTaxableIncome: federalTaxableIncome
            )
        }
    }

    private static func taxableIncome(
        using rule: TaxRule,
        configuration: EarningsConfiguration,
        federalTaxableIncome: Double
    ) -> Double {
        let baseAmount = taxableBaseAmount(
            for: rule.taxableBase,
            configuration: configuration,
            federalTaxableIncome: federalTaxableIncome
        )
        let deduction = rule.standardDeductions?[configuration.filingStatus] ?? 0
        return max(baseAmount - deduction, 0)
    }

    private static func taxableBaseAmount(
        for base: TaxableBase,
        configuration: EarningsConfiguration,
        federalTaxableIncome: Double
    ) -> Double {
        switch base {
        case .taxableCompensation:
            return taxableCompensation(configuration)
        case .federalTaxableIncome:
            return federalTaxableIncome
        case .pennsylvaniaWages:
            return configuration.annualTaxableWagesForPennsylvania
        }
    }

    private static func taxableCompensation(_ configuration: EarningsConfiguration) -> Double {
        max(
            configuration.annualGrossIncome
                - configuration.annualPretaxBenefits
                - configuration.annualRetirementContribution,
            0
        )
    }

    private static func exemptionAllowance(
        using rule: ExemptionRule?,
        filingStatus: FilingStatus,
        taxableCompensation: Double
    ) -> Double {
        guard let rule else { return 0 }

        let threshold = filingStatus == .marriedJoint
            ? rule.marriedJointThreshold
            : rule.singleThreshold

        guard taxableCompensation <= threshold else { return 0 }

        switch filingStatus {
        case .single, .headOfHousehold:
            return rule.amount
        case .marriedJoint:
            return rule.amount * 2
        }
    }

    private static func newYorkRecaptureTax(
        using rule: TaxRule,
        configuration: EarningsConfiguration,
        federalTaxableIncome: Double
    ) -> Double {
        let agi = taxableBaseAmount(
            for: rule.taxableBase,
            configuration: configuration,
            federalTaxableIncome: federalTaxableIncome
        )
        let taxableIncome = max(agi - (rule.standardDeductions?[configuration.filingStatus] ?? 0), 0)
        let schedule = rule.brackets?[configuration.filingStatus] ?? []
        let scheduleTax = tax(using: schedule, taxableIncome: taxableIncome)

        if
            let highIncomeThreshold = rule.highIncomeFlatThreshold,
            let highIncomeRate = rule.highIncomeFlatRate,
            agi > highIncomeThreshold
        {
            return taxableIncome * highIncomeRate
        }

        guard let profile = rule.recapture?[configuration.filingStatus] else {
            return scheduleTax
        }

        guard agi > profile.blendStartAGI else {
            return scheduleTax
        }

        if taxableIncome <= profile.blendUpperTaxableIncome {
            let flatTax = taxableIncome * profile.blendFlatRate

            if agi >= profile.blendStartAGI + profile.blendWidth {
                return flatTax
            }

            let blend = (agi - profile.blendStartAGI) / profile.blendWidth
            return scheduleTax + ((flatTax - scheduleTax) * blend)
        }

        for band in profile.bands {
            if let upperBound = band.taxableIncomeUpperBound, taxableIncome > upperBound {
                continue
            }

            return recapturedTax(
                agi: agi,
                taxableIncome: taxableIncome,
                lowerBound: band.lowerBound,
                baseAmount: band.baseAmount,
                incrementalBenefit: band.incrementalBenefit,
                rampWidth: profile.rampWidth,
                schedule: schedule
            )
        }

        return scheduleTax
    }

    private static func recapturedTax(
        agi: Double,
        taxableIncome: Double,
        lowerBound: Double,
        baseAmount: Double,
        incrementalBenefit: Double,
        rampWidth: Double,
        schedule: [TaxFormula]
    ) -> Double {
        let scheduleTax = tax(using: schedule, taxableIncome: taxableIncome)
        let ramp = min(max((agi - lowerBound) / rampWidth, 0), 1)
        return scheduleTax + baseAmount + (incrementalBenefit * ramp)
    }

    private static func tax(using schedule: [TaxFormula], taxableIncome: Double) -> Double {
        guard taxableIncome > 0 else { return 0 }

        for formula in schedule {
            if let upperBound = formula.upperBound, taxableIncome > upperBound {
                continue
            }

            return formula.baseTax + ((taxableIncome - formula.lowerBound) * formula.marginalRate)
        }

        guard let lastFormula = schedule.last else { return 0 }
        return lastFormula.baseTax + ((taxableIncome - lastFormula.lowerBound) * lastFormula.marginalRate)
    }
}
