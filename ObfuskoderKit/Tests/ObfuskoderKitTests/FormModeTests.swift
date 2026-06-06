import Testing
import Foundation
@testable import ObfuskoderKit

@Test func formModeIsCodableRoundTrip() throws {
    for mode in FormMode.allCases {
        let data = try JSONEncoder().encode(mode)
        let back = try JSONDecoder().decode(FormMode.self, from: data)
        #expect(back == mode)
    }
    #expect(FormMode.basic.rawValue == "basic")
    #expect(FormMode.advanced.rawValue == "advanced")
}
