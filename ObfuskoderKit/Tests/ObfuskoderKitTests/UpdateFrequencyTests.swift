import Testing
import Foundation
import ObfuskoderKit

@Test func neverDisablesAutomaticChecks() {
    #expect(UpdateFrequency.never.automaticallyChecks == false)
    #expect(UpdateFrequency.never.checkInterval == nil)
}

@Test func cadencesEnableChecksWithExpectedIntervals() {
    #expect(UpdateFrequency.daily.automaticallyChecks == true)
    #expect(UpdateFrequency.daily.checkInterval == 86_400)
    #expect(UpdateFrequency.weekly.checkInterval == 604_800)
    #expect(UpdateFrequency.monthly.checkInterval == 2_592_000)
}

@Test func defaultCadenceIsMonthly() {
    #expect(AppConfig.defaultUpdateFrequency == .monthly)
}

// @AppStorage persists the rawValue; guard against accidental renames that
// would silently reset every user's saved cadence.
@Test func rawValuesAreStableForPersistence() {
    #expect(UpdateFrequency.monthly.rawValue == "monthly")
    #expect(UpdateFrequency(rawValue: "weekly") == .weekly)
    #expect(UpdateFrequency.allCases.count == 4)
}
