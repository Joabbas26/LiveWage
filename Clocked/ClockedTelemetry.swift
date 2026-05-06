//
//  ClockedTelemetry.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import Foundation
import OSLog

struct ClockedTelemetry {
    static let shared = ClockedTelemetry()

    private let logger = Logger(
        subsystem: "JoabBastidas.Clocked",
        category: "Telemetry"
    )

    func stateRestored(streamCount: Int, historyCount: Int, hasActiveSession: Bool) {
        logger.info(
            "state_restored streams=\(streamCount, privacy: .public) history=\(historyCount, privacy: .public) active_session=\(hasActiveSession, privacy: .public)"
        )
    }

    func legacyDefaultsMigrated(streamCount: Int, historyCount: Int, hasActiveSession: Bool) {
        logger.notice(
            "legacy_defaults_migrated streams=\(streamCount, privacy: .public) history=\(historyCount, privacy: .public) active_session=\(hasActiveSession, privacy: .public)"
        )
    }

    func corruptStateRecovered() {
        logger.error("corrupt_state_recovered_using_defaults")
    }

    func taxCatalogFallback(reason: String) {
        logger.error("tax_catalog_fallback reason=\(reason, privacy: .public)")
    }

    func sessionStarted(streamID: UUID, scheduledWorkday: Int) {
        logger.info(
            "session_started stream_id=\(streamID.uuidString, privacy: .private(mask: .hash)) scheduled_workday=\(scheduledWorkday, privacy: .public)"
        )
    }

    func sessionPaused(streamID: UUID) {
        logger.info("session_paused stream_id=\(streamID.uuidString, privacy: .private(mask: .hash))")
    }

    func sessionResumed(streamID: UUID) {
        logger.info("session_resumed stream_id=\(streamID.uuidString, privacy: .private(mask: .hash))")
    }

    func sessionStopped(streamID: UUID, reason: String) {
        logger.info(
            "session_stopped stream_id=\(streamID.uuidString, privacy: .private(mask: .hash)) reason=\(reason, privacy: .public)"
        )
    }

    func weeklySummaryShared(daysWorked: Int, hasEarnings: Bool) {
        logger.info(
            "weekly_summary_shared days_worked=\(daysWorked, privacy: .public) has_earnings=\(hasEarnings, privacy: .public)"
        )
    }
}
