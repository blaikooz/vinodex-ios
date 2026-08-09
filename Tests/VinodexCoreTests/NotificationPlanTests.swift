import Testing
import Foundation
@testable import VinodexCore

@Suite("Notification plan")
struct NotificationPlanTests {
    private let today = 20_670

    @Test("a fresh morning schedules both reminders for today")
    func morningSchedulesBoth() {
        let plan = NotificationPlan.requests(today: today, todayDone: false, streak: 5, hourNow: 8)
        let mine = plan.filter { $0.day == today }
        #expect(mine.count == 2)
        #expect(mine.contains { $0.kind == .daily })
        #expect(mine.contains { $0.kind == .streakAtRisk })
    }

    /// The bug D1 names outright: do not nag somebody who already played.
    @Test("a paper already sat cancels today entirely")
    func doneDayIsSilent() {
        let plan = NotificationPlan.requests(today: today, todayDone: true, streak: 5, hourNow: 8)
        #expect(!plan.contains { $0.day == today })
        // Tomorrow onward is still planned — the day being done says nothing
        // about the next one.
        #expect(plan.contains { $0.day == today + 1 })
    }

    @Test("no streak means no streak warning, ever")
    func noStreakNoWarning() {
        let plan = NotificationPlan.requests(today: today, todayDone: false, streak: 0, hourNow: 8)
        #expect(!plan.contains { $0.kind == .streakAtRisk })
        #expect(plan.contains { $0.kind == .daily })
    }

    @Test("a reminder whose hour has passed is not scheduled into the past")
    func pastHoursSkipped() {
        let plan = NotificationPlan.requests(today: today, todayDone: false, streak: 5, hourNow: 12)
        let mine = plan.filter { $0.day == today }
        // 10:00 has gone; 20:00 has not.
        #expect(!mine.contains { $0.kind == .daily })
        #expect(mine.contains { $0.kind == .streakAtRisk })
    }

    @Test("late at night today is done with, but the horizon is not")
    func lateEveningRollsForward() {
        let plan = NotificationPlan.requests(today: today, todayDone: false, streak: 5, hourNow: 23)
        #expect(!plan.contains { $0.day == today })
        #expect(plan.contains { $0.day == today + 1 })
    }

    @Test("identifiers are stable and unique, so re-planning replaces")
    func identifiersAreStableAndUnique() {
        let first = NotificationPlan.requests(today: today, todayDone: false, streak: 5, hourNow: 8)
        let again = NotificationPlan.requests(today: today, todayDone: false, streak: 5, hourNow: 8)
        #expect(first.map(\.id) == again.map(\.id))
        #expect(Set(first.map(\.id)).count == first.count)
    }

    /// iOS keeps only the 64 soonest pending requests and drops the rest
    /// silently, so the horizon has to stay well under it by construction.
    @Test("the horizon stays far under the system's pending limit")
    func withinPendingLimit() {
        let plan = NotificationPlan.requests(today: today, todayDone: false, streak: 9, hourNow: 0)
        #expect(plan.count <= NotificationPlan.horizon * NotificationPlan.Kind.allCases.count)
        #expect(plan.count < 64)
    }

    @Test("the warning reads naturally at one day and at many")
    func bodyGrammar() {
        #expect(NotificationPlan.body(for: .streakAtRisk, streak: 1).contains("one-day"))
        #expect(NotificationPlan.body(for: .streakAtRisk, streak: 12).contains("12 days"))
    }

    @Test("the daily reminder fires before the risk warning")
    func dailyComesFirst() {
        #expect(NotificationPlan.dailyHour < NotificationPlan.riskHour)
    }
}
