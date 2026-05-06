import Foundation

extension GotoSettings {
    private static let menuBarEnabledKey = "Goto.menuBarEnabled"
    private static let menuBarProjectGroupingEnabledKey = "Goto.menuBarProjectGroupingEnabled"

    static func isMenuBarEnabled() -> Bool {
        return userDefaults.bool(forKey: menuBarEnabledKey)
    }

    static func setMenuBarEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: menuBarEnabledKey)
    }

    static func isMenuBarProjectGroupingEnabled() -> Bool {
        return userDefaults.bool(forKey: menuBarProjectGroupingEnabledKey)
    }

    static func setMenuBarProjectGroupingEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: menuBarProjectGroupingEnabledKey)
    }
}
