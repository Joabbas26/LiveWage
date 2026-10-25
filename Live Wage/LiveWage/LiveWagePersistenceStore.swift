//
//  LiveWagePersistenceStore.swift
//  LiveWage
//
//  Created by Codex on 5/5/26.
//

import Foundation
import OSLog

private let persistenceLogger = Logger(
    subsystem: "JoabBastidas.LiveWage",
    category: "Persistence"
)

struct LiveWagePersistedState: Codable, Equatable {
    var workspace: LiveWageWorkspace
    var history: [WorkdayRecord]
    var activeSession: WorkSession?
    var settings: LiveWageLocalSettings = .default

    init(
        workspace: LiveWageWorkspace,
        history: [WorkdayRecord],
        activeSession: WorkSession? = nil,
        settings: LiveWageLocalSettings = .default
    ) {
        self.workspace = workspace
        self.history = history
        self.activeSession = activeSession
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case workspace
        case history
        case activeSession
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspace = try container.decode(LiveWageWorkspace.self, forKey: .workspace)
        history = try container.decodeIfPresent([WorkdayRecord].self, forKey: .history) ?? []
        activeSession = try container.decodeIfPresent(WorkSession.self, forKey: .activeSession)
        settings = try container.decodeIfPresent(LiveWageLocalSettings.self, forKey: .settings) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workspace, forKey: .workspace)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(activeSession, forKey: .activeSession)
        try container.encode(settings, forKey: .settings)
    }

    static let `default`: LiveWagePersistedState = {
        let primaryStream = IncomeStream.primary(configuration: .default)
        return LiveWagePersistedState(
            workspace: LiveWageWorkspace(
                streams: [primaryStream],
                selectedStreamID: primaryStream.id
            ),
            history: [],
            activeSession: nil,
            settings: .default
        )
    }()

    func normalized() -> LiveWagePersistedState {
        let normalizedWorkspace = workspace.normalized()
        return LiveWagePersistedState(
            workspace: normalizedWorkspace,
            history: history.sorted { $0.completedAt > $1.completedAt },
            activeSession: activeSession,
            settings: settings
        )
    }
}

final class LiveWagePersistenceStore {
    static let stateFileName = "LiveWageState-v1.json"

    private let telemetry = LiveWageTelemetry.shared
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let directoryURL: URL
    private let stateURL: URL
    private let workspaceKey = "liveWage.workspace.v1"
    private let historyKey = "liveWage.history.v1"
    private let legacyConfigurationKey = "liveWage.configuration.v2"
    private let sessionKey = "liveWage.session.v2"

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaults = defaults

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = baseURL.appendingPathComponent("LiveWage", isDirectory: true)
        }

        self.stateURL = self.directoryURL.appendingPathComponent(Self.stateFileName, isDirectory: false)
    }

    func loadState() -> LiveWagePersistedState {
        if let diskState = loadDiskState() {
            return diskState.normalized()
        }

        guard let legacyState = loadLegacyState() else {
            return .default
        }

        let normalizedLegacyState = legacyState.normalized()
        saveState(normalizedLegacyState)
        removeLegacyDefaults()
        telemetry.legacyDefaultsMigrated(
            streamCount: normalizedLegacyState.workspace.streams.count,
            historyCount: normalizedLegacyState.history.count,
            hasActiveSession: normalizedLegacyState.activeSession != nil
        )
        return normalizedLegacyState
    }

    func saveState(_ state: LiveWagePersistedState) {
        let normalizedState = state.normalized()

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try Self.encoder.encode(normalizedState)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            persistenceLogger.error("Failed to persist state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadDiskState() -> LiveWagePersistedState? {
        guard fileManager.fileExists(atPath: stateURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: stateURL)
            return try Self.decoder.decode(LiveWagePersistedState.self, from: data)
        } catch {
            persistenceLogger.error("Failed to load persisted state: \(error.localizedDescription, privacy: .public)")
            telemetry.corruptStateRecovered()
            return nil
        }
    }

    private func loadLegacyState() -> LiveWagePersistedState? {
        let workspace: LiveWageWorkspace

        if
            let data = defaults.data(forKey: workspaceKey),
            let decoded = try? Self.decoder.decode(LiveWageWorkspace.self, from: data),
            !decoded.streams.isEmpty
        {
            workspace = decoded.normalized()
        } else if
            let data = defaults.data(forKey: legacyConfigurationKey),
            let legacyConfiguration = try? Self.decoder.decode(EarningsConfiguration.self, from: data)
        {
            let primaryStream = IncomeStream.primary(configuration: legacyConfiguration)
            workspace = LiveWageWorkspace(
                streams: [primaryStream],
                selectedStreamID: primaryStream.id
            )
        } else {
            workspace = .default
        }

        let history: [WorkdayRecord]
        if
            let data = defaults.data(forKey: historyKey),
            let decoded = try? Self.decoder.decode([WorkdayRecord].self, from: data)
        {
            history = decoded
        } else {
            history = []
        }

        let session: WorkSession?
        if
            let data = defaults.data(forKey: sessionKey),
            let decoded = try? Self.decoder.decode(WorkSession.self, from: data)
        {
            session = decoded
        } else {
            session = nil
        }

        let hasLegacyData = defaults.data(forKey: workspaceKey) != nil
            || defaults.data(forKey: historyKey) != nil
            || defaults.data(forKey: sessionKey) != nil
            || defaults.data(forKey: legacyConfigurationKey) != nil

        guard hasLegacyData else { return nil }

        return LiveWagePersistedState(
            workspace: workspace,
            history: history,
            activeSession: session
        )
    }

    private func removeLegacyDefaults() {
        defaults.removeObject(forKey: workspaceKey)
        defaults.removeObject(forKey: historyKey)
        defaults.removeObject(forKey: sessionKey)
        defaults.removeObject(forKey: legacyConfigurationKey)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
