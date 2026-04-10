import Foundation

enum AppConstants {
    static let apiBaseURL = URL(string: "https://codestudy-nine.vercel.app")!
    static let maxSessionsPerDay = 5
    static let maxTurnsPerSession = 20
    static let appGroupIdentifier = "group.com.itlearning.codestudy"
    static let bundleIdentifier = "com.itlearning.codestudy"

    #if DEBUG
    static let debugAPIBaseURL = URL(string: "http://localhost:3000")!
    #endif
}
