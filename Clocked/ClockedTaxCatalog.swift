//
//  ClockedTaxCatalog.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import Foundation
import OSLog

private let taxCatalogLogger = Logger(
    subsystem: "JoabBastidas.Clocked",
    category: "TaxCatalog"
)

enum ClockedTaxCatalogLoadIssue: Equatable {
    case bundledDataUnavailable(String)

    var description: String {
        switch self {
        case .bundledDataUnavailable(let message):
            return message
        }
    }
}

struct ClockedTaxCatalog {
    static let shared = ClockedTaxCatalog(bundle: .main)

    let table: ClockedTaxTable
    let availableLocations: [LocationOption]
    let loadingIssue: ClockedTaxCatalogLoadIssue?
    private let profilesByID: [String: LocationTaxProfile]

    init(
        table: ClockedTaxTable,
        loadingIssue: ClockedTaxCatalogLoadIssue? = nil
    ) {
        self.table = table
        self.loadingIssue = loadingIssue
        self.availableLocations = Self.makeAvailableLocations(from: table)
        self.profilesByID = Dictionary(uniqueKeysWithValues: table.locations.map { ($0.id, $0) })
    }

    init(bundle: Bundle) {
        do {
            let table = try ClockedTaxTable.loadBundled(bundle: bundle)
            self.init(table: table)
        } catch {
            taxCatalogLogger.error("Tax catalog fallback engaged: \(error.localizedDescription, privacy: .public)")
            ClockedTelemetry.shared.taxCatalogFallback(reason: error.localizedDescription)
            self.init(
                table: .fallbackBaseline(),
                loadingIssue: .bundledDataUnavailable(error.localizedDescription)
            )
        }
    }

    func profile(for location: LocationOption) -> LocationTaxProfile {
        if let profile = profilesByID[location.rawValue] {
            return profile
        }

        if let fallback = profilesByID[LocationOption.newYorkCity.rawValue] {
            return fallback
        }

        return .placeholder(
            for: location,
            taxYear: table.taxYear,
            bundledDataUnavailable: loadingIssue != nil
        )
    }

    func profileIfAvailable(for location: LocationOption) -> LocationTaxProfile? {
        profilesByID[location.rawValue]
    }

    private static func makeAvailableLocations(from table: ClockedTaxTable) -> [LocationOption] {
        guard !table.locations.isEmpty else {
            return LocationOption.bootstrapCases
        }

        return table.locations
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map { LocationOption(rawValue: $0.id) }
    }
}

struct ClockedTaxTable: Decodable {
    let taxYear: Int
    let federal: FederalTaxTable
    let fica: FICATaxTable
    let locations: [LocationTaxProfile]

    static func loadBundled(bundle: Bundle = .main) throws -> ClockedTaxTable {
        guard let url = bundle.url(forResource: "ClockedTaxData2025", withExtension: "json") else {
            throw ClockedTaxCatalogDataError.missingBundledFile
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ClockedTaxTable.self, from: data)
        } catch {
            throw ClockedTaxCatalogDataError.decodeFailed(error.localizedDescription)
        }
    }

    static func fallbackBaseline() -> ClockedTaxTable {
        ClockedTaxTable(
            taxYear: 2025,
            federal: FederalTaxTable(
                standardDeductions: FilingStatusValues(
                    single: 15_750,
                    marriedJoint: 31_500,
                    headOfHousehold: 23_625
                ),
                brackets: FilingStatusValues(
                    single: [
                        TaxFormula(lowerBound: 0, upperBound: 11_925, baseTax: 0, marginalRate: 0.10),
                        TaxFormula(lowerBound: 11_925, upperBound: 48_475, baseTax: 1_192.5, marginalRate: 0.12),
                        TaxFormula(lowerBound: 48_475, upperBound: 103_350, baseTax: 5_578.5, marginalRate: 0.22),
                        TaxFormula(lowerBound: 103_350, upperBound: 197_300, baseTax: 17_651, marginalRate: 0.24),
                        TaxFormula(lowerBound: 197_300, upperBound: 250_525, baseTax: 40_199, marginalRate: 0.32),
                        TaxFormula(lowerBound: 250_525, upperBound: 626_350, baseTax: 57_231, marginalRate: 0.35),
                        TaxFormula(lowerBound: 626_350, upperBound: nil, baseTax: 188_769.75, marginalRate: 0.37)
                    ],
                    marriedJoint: [
                        TaxFormula(lowerBound: 0, upperBound: 23_850, baseTax: 0, marginalRate: 0.10),
                        TaxFormula(lowerBound: 23_850, upperBound: 96_950, baseTax: 2_385, marginalRate: 0.12),
                        TaxFormula(lowerBound: 96_950, upperBound: 206_700, baseTax: 11_157, marginalRate: 0.22),
                        TaxFormula(lowerBound: 206_700, upperBound: 394_600, baseTax: 35_302, marginalRate: 0.24),
                        TaxFormula(lowerBound: 394_600, upperBound: 501_050, baseTax: 80_398, marginalRate: 0.32),
                        TaxFormula(lowerBound: 501_050, upperBound: 751_600, baseTax: 114_462, marginalRate: 0.35),
                        TaxFormula(lowerBound: 751_600, upperBound: nil, baseTax: 202_154.5, marginalRate: 0.37)
                    ],
                    headOfHousehold: [
                        TaxFormula(lowerBound: 0, upperBound: 17_000, baseTax: 0, marginalRate: 0.10),
                        TaxFormula(lowerBound: 17_000, upperBound: 64_850, baseTax: 1_700, marginalRate: 0.12),
                        TaxFormula(lowerBound: 64_850, upperBound: 103_350, baseTax: 7_442, marginalRate: 0.22),
                        TaxFormula(lowerBound: 103_350, upperBound: 197_300, baseTax: 15_912, marginalRate: 0.24),
                        TaxFormula(lowerBound: 197_300, upperBound: 250_500, baseTax: 38_460, marginalRate: 0.32),
                        TaxFormula(lowerBound: 250_500, upperBound: 626_350, baseTax: 55_484, marginalRate: 0.35),
                        TaxFormula(lowerBound: 626_350, upperBound: nil, baseTax: 187_031.5, marginalRate: 0.37)
                    ]
                )
            ),
            fica: FICATaxTable(
                socialSecurityRate: 0.062,
                socialSecurityWageBase: 176_100,
                medicareRate: 0.0145,
                additionalMedicareRate: 0.009,
                additionalMedicareThresholds: FilingStatusValues(
                    single: 200_000,
                    marriedJoint: 250_000,
                    headOfHousehold: 200_000
                )
            ),
            locations: []
        )
    }
}

enum ClockedTaxCatalogDataError: LocalizedError {
    case missingBundledFile
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledFile:
            return "ClockedTaxData2025.json is missing from the app bundle."
        case .decodeFailed(let message):
            return "Unable to decode ClockedTaxData2025.json: \(message)"
        }
    }
}

struct FederalTaxTable: Decodable {
    let standardDeductions: FilingStatusValues<Double>
    let brackets: FilingStatusValues<[TaxFormula]>
}

struct FICATaxTable: Decodable {
    let socialSecurityRate: Double
    let socialSecurityWageBase: Double
    let medicareRate: Double
    let additionalMedicareRate: Double
    let additionalMedicareThresholds: FilingStatusValues<Double>
}

struct LocationTaxProfile: Decodable {
    let id: String
    let displayName: String
    let shortName: String
    let stateCode: String
    let taxLabel: String
    let assumptionLabel: String
    let stateTaxTitle: String
    let localTaxTitle: String?
    let stateRule: TaxRule
    let localRule: TaxRule?

    static func placeholder(
        for location: LocationOption,
        taxYear: Int,
        bundledDataUnavailable: Bool
    ) -> LocationTaxProfile {
        let assumptionLabel: String

        if bundledDataUnavailable {
            assumptionLabel = "Bundled \(taxYear) location tax data is unavailable right now, so this estimate falls back to federal income tax and FICA only."
        } else {
            assumptionLabel = "This location is not in the bundled \(taxYear) tax catalog yet, so this estimate falls back to federal income tax and FICA only."
        }

        return LocationTaxProfile(
            id: location.rawValue,
            displayName: location.fallbackDisplayName,
            shortName: location.fallbackShortName,
            stateCode: "--",
            taxLabel: "Federal + FICA estimate",
            assumptionLabel: assumptionLabel,
            stateTaxTitle: "State income tax",
            localTaxTitle: nil,
            stateRule: .none,
            localRule: nil
        )
    }
}

struct TaxRule: Decodable {
    let strategy: TaxRuleStrategy
    let taxableBase: TaxableBase
    let flatRate: Double?
    let standardDeductions: FilingStatusValues<Double>?
    let personalCredits: FilingStatusValues<Double>?
    let brackets: FilingStatusValues<[TaxFormula]>?
    let surtaxThreshold: Double?
    let surtaxRate: Double?
    let highIncomeFlatThreshold: Double?
    let highIncomeFlatRate: Double?
    let recapture: FilingStatusValues<RecaptureProfile>?
    let exemption: ExemptionRule?

    static let none = TaxRule(
        strategy: .none,
        taxableBase: .taxableCompensation,
        flatRate: nil,
        standardDeductions: nil,
        personalCredits: nil,
        brackets: nil,
        surtaxThreshold: nil,
        surtaxRate: nil,
        highIncomeFlatThreshold: nil,
        highIncomeFlatRate: nil,
        recapture: nil,
        exemption: nil
    )
}

enum TaxRuleStrategy: String, Decodable {
    case none
    case flat
    case progressive
    case progressiveWithCredit
    case flatWithExemption
    case flatWithSurtax
    case newYorkRecapture
}

enum TaxableBase: String, Decodable {
    case taxableCompensation
    case federalTaxableIncome
    case pennsylvaniaWages
}

struct TaxFormula: Decodable {
    let lowerBound: Double
    let upperBound: Double?
    let baseTax: Double
    let marginalRate: Double
}

struct ExemptionRule: Decodable {
    let amount: Double
    let singleThreshold: Double
    let marriedJointThreshold: Double
}

struct RecaptureProfile: Decodable {
    let blendStartAGI: Double
    let blendWidth: Double
    let blendUpperTaxableIncome: Double
    let blendFlatRate: Double
    let rampWidth: Double
    let bands: [RecaptureBand]
}

struct RecaptureBand: Decodable {
    let taxableIncomeUpperBound: Double?
    let lowerBound: Double
    let baseAmount: Double
    let incrementalBenefit: Double
}

struct FilingStatusValues<Value: Decodable>: Decodable {
    let single: Value
    let marriedJoint: Value
    let headOfHousehold: Value

    subscript(_ filingStatus: FilingStatus) -> Value {
        switch filingStatus {
        case .single:
            return single
        case .marriedJoint:
            return marriedJoint
        case .headOfHousehold:
            return headOfHousehold
        }
    }
}
