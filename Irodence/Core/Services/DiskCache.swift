import Foundation

/// Tiny JSON disk cache in the Caches directory. Used so every tab can
/// render instantly from the last known data while a silent background
/// refresh swaps in fresh rows. Round-trips with plain JSONCoder, so
/// `Date` fields encode as timestamps — fine for our own write/read cycle.
enum DiskCache {
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    static func remove(key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }

    static func url(for key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("diskcache_\(key).json")
    }
}
