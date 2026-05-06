//
//  ClockedSessionCalculator.swift
//  Clocked
//
//  Created by Codex on 5/5/26.
//

import Foundation

struct ClockedSessionCalculator {
    func makeSession(
        selectedStream: IncomeStream,
        configuration: EarningsConfiguration,
        currentDate: Date,
        calendar: Calendar
    ) -> WorkSession {
        let workDate = calendar.startOfDay(for: currentDate)
        return WorkSession(
            streamID: selectedStream.id,
            streamName: selectedStream.name,
            configuration: configuration,
            workDate: workDate,
            createdAt: currentDate
        )
    }

    func snapshot(
        for session: WorkSession,
        at date: Date,
        calendar: Calendar
    ) -> SessionSnapshot {
        let estimate = ClockedTaxEngine.estimate(for: session.configuration)
        let start = session.createdAt
        let effectiveNow = session.pausedAt ?? date
        let pauseExtension = session.accumulatedPausedSeconds + currentPauseDuration(for: session, at: date)
        let end = start.addingTimeInterval(session.configuration.workDaySeconds + pauseExtension)

        let rawElapsed = max(effectiveNow.timeIntervalSince(start), 0)
        let elapsedWorkSeconds = max(rawElapsed - session.accumulatedPausedSeconds, 0)
        let cappedElapsed = min(elapsedWorkSeconds, session.configuration.workDaySeconds)
        let remainingSeconds = max(session.configuration.workDaySeconds - cappedElapsed, 0)

        let status: SessionStatus
        if date < start {
            status = .scheduled
        } else if cappedElapsed >= session.configuration.workDaySeconds {
            status = .complete
        } else if session.isPaused {
            status = .paused
        } else {
            status = .live
        }

        return SessionSnapshot(
            session: session,
            estimate: estimate,
            status: status,
            now: date,
            scheduledStart: start,
            scheduledEnd: end,
            elapsedWorkSeconds: cappedElapsed,
            remainingSeconds: remainingSeconds,
            grossEarned: cappedElapsed * estimate.grossPerSecond,
            netEarned: cappedElapsed * estimate.netPerSecond
        )
    }

    private func currentPauseDuration(
        for session: WorkSession,
        at date: Date
    ) -> Double {
        guard let pausedAt = session.pausedAt else { return 0 }
        return max(date.timeIntervalSince(pausedAt), 0)
    }

    func workdayRecord(
        from snapshot: SessionSnapshot,
        completedAt date: Date
    ) -> WorkdayRecord? {
        guard snapshot.elapsedWorkSeconds > 0 else { return nil }

        return WorkdayRecord(
            streamID: snapshot.session.streamID,
            streamName: snapshot.session.streamName,
            workDate: snapshot.session.workDate,
            completedAt: date,
            configuration: snapshot.session.configuration,
            grossEarned: snapshot.grossEarned,
            netEarned: snapshot.netEarned,
            elapsedWorkSeconds: snapshot.elapsedWorkSeconds
        )
    }
}
