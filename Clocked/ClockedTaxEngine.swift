//
//  ClockedTaxEngine.swift
//  Clocked
//
//  Created by Codex on 5/4/26.
//

import Foundation

enum ClockedTaxEngine {
    static let taxYear = 2025

    static func estimate(for configuration: EarningsConfiguration) -> EarningsEstimate {
        let annualBasePay = configuration.annualBaseIncome
        let annualBonus = configuration.annualBonusAmount
        let annualGross = configuration.annualGrossIncome
        let annualPretaxBenefits = configuration.annualPretaxBenefits
        let annualRetirementContribution = configuration.annualRetirementContribution

        let federalTaxableIncome = max(
            configuration.annualTaxableWagesForFederal - federalStandardDeduction(for: configuration.filingStatus),
            0
        )
        let federalIncomeTax = federalIncomeTax(
            for: federalTaxableIncome,
            filingStatus: configuration.filingStatus
        )

        let socialSecurityTax = min(configuration.annualTaxableWagesForFICA, 176_100) * 0.062
        let medicareTax = medicareTax(
            for: configuration.annualTaxableWagesForFICA,
            filingStatus: configuration.filingStatus
        )

        let stateIncomeTax = stateIncomeTax(
            for: configuration,
            federalTaxableIncome: federalTaxableIncome
        )
        let localIncomeTax = localIncomeTax(for: configuration)

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

    private static func federalIncomeTax(for taxableIncome: Double, filingStatus: FilingStatus) -> Double {
        tax(using: federalSchedule(for: filingStatus), taxableIncome: taxableIncome)
    }

    private static func federalStandardDeduction(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single:
            return 15_750
        case .marriedJoint:
            return 31_500
        case .headOfHousehold:
            return 23_625
        }
    }

    private static func federalSchedule(for filingStatus: FilingStatus) -> [TaxFormula] {
        switch filingStatus {
        case .single:
            return [
                TaxFormula(lowerBound: 0, upperBound: 11_925, baseTax: 0, marginalRate: 0.10),
                TaxFormula(lowerBound: 11_925, upperBound: 48_475, baseTax: 1_192.50, marginalRate: 0.12),
                TaxFormula(lowerBound: 48_475, upperBound: 103_350, baseTax: 5_578.50, marginalRate: 0.22),
                TaxFormula(lowerBound: 103_350, upperBound: 197_300, baseTax: 17_651.00, marginalRate: 0.24),
                TaxFormula(lowerBound: 197_300, upperBound: 250_525, baseTax: 40_199.00, marginalRate: 0.32),
                TaxFormula(lowerBound: 250_525, upperBound: 626_350, baseTax: 57_231.00, marginalRate: 0.35),
                TaxFormula(lowerBound: 626_350, upperBound: nil, baseTax: 188_769.75, marginalRate: 0.37)
            ]
        case .marriedJoint:
            return [
                TaxFormula(lowerBound: 0, upperBound: 23_850, baseTax: 0, marginalRate: 0.10),
                TaxFormula(lowerBound: 23_850, upperBound: 96_950, baseTax: 2_385.00, marginalRate: 0.12),
                TaxFormula(lowerBound: 96_950, upperBound: 206_700, baseTax: 11_157.00, marginalRate: 0.22),
                TaxFormula(lowerBound: 206_700, upperBound: 394_600, baseTax: 35_302.00, marginalRate: 0.24),
                TaxFormula(lowerBound: 394_600, upperBound: 501_050, baseTax: 80_398.00, marginalRate: 0.32),
                TaxFormula(lowerBound: 501_050, upperBound: 751_600, baseTax: 114_462.00, marginalRate: 0.35),
                TaxFormula(lowerBound: 751_600, upperBound: nil, baseTax: 202_154.50, marginalRate: 0.37)
            ]
        case .headOfHousehold:
            return [
                TaxFormula(lowerBound: 0, upperBound: 17_000, baseTax: 0, marginalRate: 0.10),
                TaxFormula(lowerBound: 17_000, upperBound: 64_850, baseTax: 1_700.00, marginalRate: 0.12),
                TaxFormula(lowerBound: 64_850, upperBound: 103_350, baseTax: 7_442.00, marginalRate: 0.22),
                TaxFormula(lowerBound: 103_350, upperBound: 197_300, baseTax: 15_912.00, marginalRate: 0.24),
                TaxFormula(lowerBound: 197_300, upperBound: 250_500, baseTax: 38_460.00, marginalRate: 0.32),
                TaxFormula(lowerBound: 250_500, upperBound: 626_350, baseTax: 55_484.00, marginalRate: 0.35),
                TaxFormula(lowerBound: 626_350, upperBound: nil, baseTax: 187_031.50, marginalRate: 0.37)
            ]
        }
    }

    private static func medicareTax(for taxableWages: Double, filingStatus: FilingStatus) -> Double {
        let threshold: Double

        switch filingStatus {
        case .single, .headOfHousehold:
            threshold = 200_000
        case .marriedJoint:
            threshold = 250_000
        }

        let baseTax = taxableWages * 0.0145
        let additionalTax = max(taxableWages - threshold, 0) * 0.009
        return baseTax + additionalTax
    }

    private static func stateIncomeTax(
        for configuration: EarningsConfiguration,
        federalTaxableIncome: Double
    ) -> Double {
        switch configuration.location {
        case .newYorkCity:
            return newYorkStateTax(
                for: taxableCompensation(configuration),
                filingStatus: configuration.filingStatus
            )
        case .california:
            return californiaTax(
                for: taxableCompensation(configuration),
                filingStatus: configuration.filingStatus
            )
        case .illinois:
            return illinoisTax(
                for: taxableCompensation(configuration),
                filingStatus: configuration.filingStatus
            )
        case .massachusetts:
            return massachusettsTax(
                for: taxableCompensation(configuration),
                filingStatus: configuration.filingStatus
            )
        case .colorado:
            return coloradoTax(for: federalTaxableIncome)
        case .pennsylvania:
            return pennsylvaniaTax(for: configuration.annualTaxableWagesForPennsylvania)
        case .texas, .florida, .washington:
            return 0
        }
    }

    private static func localIncomeTax(for configuration: EarningsConfiguration) -> Double {
        switch configuration.location {
        case .newYorkCity:
            let taxableIncome = max(
                taxableCompensation(configuration) - newYorkStandardDeduction(for: configuration.filingStatus),
                0
            )
            return tax(using: newYorkCitySchedule(for: configuration.filingStatus), taxableIncome: taxableIncome)
        case .california, .illinois, .texas, .florida, .washington, .massachusetts, .colorado, .pennsylvania:
            return 0
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

    private static func newYorkStateTax(for taxableCompensation: Double, filingStatus: FilingStatus) -> Double {
        let taxableIncome = max(taxableCompensation - newYorkStandardDeduction(for: filingStatus), 0)
        let agi = taxableCompensation

        if agi > 25_000_000 {
            return taxableIncome * 0.109
        }

        switch filingStatus {
        case .marriedJoint:
            if agi <= 107_650 {
                return tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
            }

            if taxableIncome <= 161_550 {
                if agi >= 157_650 {
                    return taxableIncome * 0.055
                }

                let scheduleTax = tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
                let flatTax = taxableIncome * 0.055
                let blend = (agi - 107_650) / 50_000
                return scheduleTax + ((flatTax - scheduleTax) * blend)
            }

            if taxableIncome <= 323_200 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 161_550,
                    baseAmount: 333,
                    incrementalBenefit: 807,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            if taxableIncome <= 2_155_350 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 323_200,
                    baseAmount: 1_140,
                    incrementalBenefit: 2_747,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            if taxableIncome <= 5_000_000 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 2_155_350,
                    baseAmount: 3_887,
                    incrementalBenefit: 60_350,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            return recapturedTax(
                agi: agi,
                taxableIncome: taxableIncome,
                lowerBound: 5_000_000,
                baseAmount: 64_237,
                incrementalBenefit: 32_500,
                schedule: newYorkStateSchedule(for: filingStatus)
            )

        case .single:
            if agi <= 107_650 {
                return tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
            }

            if taxableIncome <= 215_400 {
                if agi >= 157_650 {
                    return taxableIncome * 0.06
                }

                let scheduleTax = tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
                let flatTax = taxableIncome * 0.06
                let blend = (agi - 107_650) / 50_000
                return scheduleTax + ((flatTax - scheduleTax) * blend)
            }

            if taxableIncome <= 1_077_550 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 215_400,
                    baseAmount: 568,
                    incrementalBenefit: 1_831,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            if taxableIncome <= 5_000_000 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 1_077_550,
                    baseAmount: 2_399,
                    incrementalBenefit: 30_172,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            return recapturedTax(
                agi: agi,
                taxableIncome: taxableIncome,
                lowerBound: 5_000_000,
                baseAmount: 32_571,
                incrementalBenefit: 32_500,
                schedule: newYorkStateSchedule(for: filingStatus)
            )

        case .headOfHousehold:
            if agi <= 107_650 {
                return tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
            }

            if taxableIncome <= 269_300 {
                if agi >= 157_650 {
                    return taxableIncome * 0.06
                }

                let scheduleTax = tax(using: newYorkStateSchedule(for: filingStatus), taxableIncome: taxableIncome)
                let flatTax = taxableIncome * 0.06
                let blend = (agi - 107_650) / 50_000
                return scheduleTax + ((flatTax - scheduleTax) * blend)
            }

            if taxableIncome <= 1_616_450 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 269_300,
                    baseAmount: 787,
                    incrementalBenefit: 2_289,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            if taxableIncome <= 5_000_000 {
                return recapturedTax(
                    agi: agi,
                    taxableIncome: taxableIncome,
                    lowerBound: 1_616_450,
                    baseAmount: 3_076,
                    incrementalBenefit: 45_261,
                    schedule: newYorkStateSchedule(for: filingStatus)
                )
            }

            return recapturedTax(
                agi: agi,
                taxableIncome: taxableIncome,
                lowerBound: 5_000_000,
                baseAmount: 48_337,
                incrementalBenefit: 32_500,
                schedule: newYorkStateSchedule(for: filingStatus)
            )
        }
    }

    private static func newYorkStandardDeduction(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single:
            return 8_000
        case .marriedJoint:
            return 16_050
        case .headOfHousehold:
            return 11_200
        }
    }

    private static func newYorkStateSchedule(for filingStatus: FilingStatus) -> [TaxFormula] {
        switch filingStatus {
        case .single:
            return [
                TaxFormula(lowerBound: 0, upperBound: 8_500, baseTax: 0, marginalRate: 0.04),
                TaxFormula(lowerBound: 8_500, upperBound: 11_700, baseTax: 340, marginalRate: 0.045),
                TaxFormula(lowerBound: 11_700, upperBound: 13_900, baseTax: 484, marginalRate: 0.0525),
                TaxFormula(lowerBound: 13_900, upperBound: 80_650, baseTax: 600, marginalRate: 0.055),
                TaxFormula(lowerBound: 80_650, upperBound: 215_400, baseTax: 4_271, marginalRate: 0.06),
                TaxFormula(lowerBound: 215_400, upperBound: 1_077_550, baseTax: 12_356, marginalRate: 0.0685),
                TaxFormula(lowerBound: 1_077_550, upperBound: 5_000_000, baseTax: 71_413, marginalRate: 0.0965),
                TaxFormula(lowerBound: 5_000_000, upperBound: 25_000_000, baseTax: 449_929, marginalRate: 0.103),
                TaxFormula(lowerBound: 25_000_000, upperBound: nil, baseTax: 2_509_929, marginalRate: 0.109)
            ]
        case .marriedJoint:
            return [
                TaxFormula(lowerBound: 0, upperBound: 17_150, baseTax: 0, marginalRate: 0.04),
                TaxFormula(lowerBound: 17_150, upperBound: 23_600, baseTax: 686, marginalRate: 0.045),
                TaxFormula(lowerBound: 23_600, upperBound: 27_900, baseTax: 976, marginalRate: 0.0525),
                TaxFormula(lowerBound: 27_900, upperBound: 161_550, baseTax: 1_202, marginalRate: 0.055),
                TaxFormula(lowerBound: 161_550, upperBound: 323_200, baseTax: 8_553, marginalRate: 0.06),
                TaxFormula(lowerBound: 323_200, upperBound: 2_155_350, baseTax: 18_252, marginalRate: 0.0685),
                TaxFormula(lowerBound: 2_155_350, upperBound: 5_000_000, baseTax: 143_754, marginalRate: 0.0965),
                TaxFormula(lowerBound: 5_000_000, upperBound: 25_000_000, baseTax: 418_263, marginalRate: 0.103),
                TaxFormula(lowerBound: 25_000_000, upperBound: nil, baseTax: 2_478_263, marginalRate: 0.109)
            ]
        case .headOfHousehold:
            return [
                TaxFormula(lowerBound: 0, upperBound: 12_800, baseTax: 0, marginalRate: 0.04),
                TaxFormula(lowerBound: 12_800, upperBound: 17_650, baseTax: 512, marginalRate: 0.045),
                TaxFormula(lowerBound: 17_650, upperBound: 20_900, baseTax: 730, marginalRate: 0.0525),
                TaxFormula(lowerBound: 20_900, upperBound: 107_650, baseTax: 901, marginalRate: 0.055),
                TaxFormula(lowerBound: 107_650, upperBound: 269_300, baseTax: 5_672, marginalRate: 0.06),
                TaxFormula(lowerBound: 269_300, upperBound: 1_616_450, baseTax: 15_371, marginalRate: 0.0685),
                TaxFormula(lowerBound: 1_616_450, upperBound: 5_000_000, baseTax: 107_651, marginalRate: 0.0965),
                TaxFormula(lowerBound: 5_000_000, upperBound: 25_000_000, baseTax: 434_163, marginalRate: 0.103),
                TaxFormula(lowerBound: 25_000_000, upperBound: nil, baseTax: 2_494_163, marginalRate: 0.109)
            ]
        }
    }

    private static func newYorkCitySchedule(for filingStatus: FilingStatus) -> [TaxFormula] {
        switch filingStatus {
        case .single:
            return [
                TaxFormula(lowerBound: 0, upperBound: 12_000, baseTax: 0, marginalRate: 0.03078),
                TaxFormula(lowerBound: 12_000, upperBound: 25_000, baseTax: 369, marginalRate: 0.03762),
                TaxFormula(lowerBound: 25_000, upperBound: 50_000, baseTax: 858, marginalRate: 0.03819),
                TaxFormula(lowerBound: 50_000, upperBound: nil, baseTax: 1_813, marginalRate: 0.03876)
            ]
        case .marriedJoint:
            return [
                TaxFormula(lowerBound: 0, upperBound: 21_600, baseTax: 0, marginalRate: 0.03078),
                TaxFormula(lowerBound: 21_600, upperBound: 45_000, baseTax: 665, marginalRate: 0.03762),
                TaxFormula(lowerBound: 45_000, upperBound: 90_000, baseTax: 1_545, marginalRate: 0.03819),
                TaxFormula(lowerBound: 90_000, upperBound: nil, baseTax: 3_264, marginalRate: 0.03876)
            ]
        case .headOfHousehold:
            return [
                TaxFormula(lowerBound: 0, upperBound: 14_400, baseTax: 0, marginalRate: 0.03078),
                TaxFormula(lowerBound: 14_400, upperBound: 30_000, baseTax: 443, marginalRate: 0.03762),
                TaxFormula(lowerBound: 30_000, upperBound: 60_000, baseTax: 1_030, marginalRate: 0.03819),
                TaxFormula(lowerBound: 60_000, upperBound: nil, baseTax: 2_176, marginalRate: 0.03876)
            ]
        }
    }

    private static func californiaTax(for taxableCompensation: Double, filingStatus: FilingStatus) -> Double {
        let taxableIncome = max(taxableCompensation - californiaStandardDeduction(for: filingStatus), 0)
        let schedule = californiaSchedule(for: filingStatus)
        let personalCredit = californiaPersonalExemptionCredit(for: filingStatus)
        return max(tax(using: schedule, taxableIncome: taxableIncome) - personalCredit, 0)
    }

    private static func californiaStandardDeduction(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single:
            return 5_706
        case .marriedJoint:
            return 11_412
        case .headOfHousehold:
            return 11_412
        }
    }

    private static func californiaPersonalExemptionCredit(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single, .headOfHousehold:
            return 153
        case .marriedJoint:
            return 306
        }
    }

    private static func californiaSchedule(for filingStatus: FilingStatus) -> [TaxFormula] {
        switch filingStatus {
        case .single:
            return [
                TaxFormula(lowerBound: 0, upperBound: 11_079, baseTax: 0, marginalRate: 0.01),
                TaxFormula(lowerBound: 11_079, upperBound: 26_264, baseTax: 110.79, marginalRate: 0.02),
                TaxFormula(lowerBound: 26_264, upperBound: 41_452, baseTax: 414.49, marginalRate: 0.04),
                TaxFormula(lowerBound: 41_452, upperBound: 57_542, baseTax: 1_022.01, marginalRate: 0.06),
                TaxFormula(lowerBound: 57_542, upperBound: 72_724, baseTax: 1_987.41, marginalRate: 0.08),
                TaxFormula(lowerBound: 72_724, upperBound: 371_479, baseTax: 3_201.97, marginalRate: 0.093),
                TaxFormula(lowerBound: 371_479, upperBound: 445_771, baseTax: 30_986.19, marginalRate: 0.103),
                TaxFormula(lowerBound: 445_771, upperBound: 742_953, baseTax: 38_638.27, marginalRate: 0.113),
                TaxFormula(lowerBound: 742_953, upperBound: nil, baseTax: 72_219.84, marginalRate: 0.123)
            ]
        case .marriedJoint:
            return [
                TaxFormula(lowerBound: 0, upperBound: 22_158, baseTax: 0, marginalRate: 0.01),
                TaxFormula(lowerBound: 22_158, upperBound: 52_528, baseTax: 221.58, marginalRate: 0.02),
                TaxFormula(lowerBound: 52_528, upperBound: 82_904, baseTax: 828.98, marginalRate: 0.04),
                TaxFormula(lowerBound: 82_904, upperBound: 115_084, baseTax: 2_044.02, marginalRate: 0.06),
                TaxFormula(lowerBound: 115_084, upperBound: 145_448, baseTax: 3_974.82, marginalRate: 0.08),
                TaxFormula(lowerBound: 145_448, upperBound: 742_958, baseTax: 6_403.94, marginalRate: 0.093),
                TaxFormula(lowerBound: 742_958, upperBound: 891_542, baseTax: 61_972.37, marginalRate: 0.103),
                TaxFormula(lowerBound: 891_542, upperBound: 1_485_906, baseTax: 77_276.52, marginalRate: 0.113),
                TaxFormula(lowerBound: 1_485_906, upperBound: nil, baseTax: 144_439.65, marginalRate: 0.123)
            ]
        case .headOfHousehold:
            return [
                TaxFormula(lowerBound: 0, upperBound: 22_173, baseTax: 0, marginalRate: 0.01),
                TaxFormula(lowerBound: 22_173, upperBound: 52_530, baseTax: 221.73, marginalRate: 0.02),
                TaxFormula(lowerBound: 52_530, upperBound: 67_716, baseTax: 828.87, marginalRate: 0.04),
                TaxFormula(lowerBound: 67_716, upperBound: 83_805, baseTax: 1_436.31, marginalRate: 0.06),
                TaxFormula(lowerBound: 83_805, upperBound: 98_990, baseTax: 2_401.65, marginalRate: 0.08),
                TaxFormula(lowerBound: 98_990, upperBound: 505_208, baseTax: 3_616.45, marginalRate: 0.093),
                TaxFormula(lowerBound: 505_208, upperBound: 606_251, baseTax: 41_394.72, marginalRate: 0.103),
                TaxFormula(lowerBound: 606_251, upperBound: 1_010_417, baseTax: 51_802.15, marginalRate: 0.113),
                TaxFormula(lowerBound: 1_010_417, upperBound: nil, baseTax: 97_472.91, marginalRate: 0.123)
            ]
        }
    }

    private static func illinoisTax(for taxableCompensation: Double, filingStatus: FilingStatus) -> Double {
        let exemptionAllowance = illinoisExemptionAllowance(for: taxableCompensation, filingStatus: filingStatus)
        let taxableIncome = max(taxableCompensation - exemptionAllowance, 0)
        return taxableIncome * 0.0495
    }

    private static func illinoisExemptionAllowance(for taxableCompensation: Double, filingStatus: FilingStatus) -> Double {
        let baseExemption = 2_850.0
        let threshold = filingStatus == .marriedJoint ? 500_000.0 : 250_000.0

        guard taxableCompensation <= threshold else { return 0 }

        switch filingStatus {
        case .single, .headOfHousehold:
            return baseExemption
        case .marriedJoint:
            return baseExemption * 2
        }
    }

    private static func massachusettsTax(for taxableCompensation: Double, filingStatus: FilingStatus) -> Double {
        let taxableIncome = max(taxableCompensation - massachusettsPersonalExemption(for: filingStatus), 0)
        let baseTax = taxableIncome * 0.05
        let surtax = max(taxableIncome - 1_083_150, 0) * 0.04
        return baseTax + surtax
    }

    private static func massachusettsPersonalExemption(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single:
            return 4_400
        case .marriedJoint:
            return 8_800
        case .headOfHousehold:
            return 6_800
        }
    }

    private static func coloradoTax(for federalTaxableIncome: Double) -> Double {
        federalTaxableIncome * 0.044
    }

    private static func pennsylvaniaTax(for taxableWages: Double) -> Double {
        taxableWages * 0.0307
    }

    private static func recapturedTax(
        agi: Double,
        taxableIncome: Double,
        lowerBound: Double,
        baseAmount: Double,
        incrementalBenefit: Double,
        schedule: [TaxFormula]
    ) -> Double {
        let scheduleTax = tax(using: schedule, taxableIncome: taxableIncome)
        let ramp = min(max((agi - lowerBound) / 50_000, 0), 1)
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

private struct TaxFormula {
    let lowerBound: Double
    let upperBound: Double?
    let baseTax: Double
    let marginalRate: Double
}
