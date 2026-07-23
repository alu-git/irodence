import Foundation

/// Runtime configuration read from Info.plist, which is populated from
/// Config/Secrets.xcconfig at build time. Never hardcode secrets in source.
enum AppConfig {
    private static func infoValue(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$") // unresolved build variable
        else {
            fatalError("Missing \(key) in Info.plist — did you create Config/Secrets.xcconfig?")
        }
        return value
    }

    static var supabaseURL: URL {
        guard let url = URL(string: infoValue("SupabaseURL")) else {
            fatalError("SupabaseURL is not a valid URL")
        }
        return url
    }

    static var supabaseAnonKey: String { infoValue("SupabaseAnonKey") }
    static var weChatAppID: String { infoValue("WeChatAppID") }
}
