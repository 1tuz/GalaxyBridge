#if !GALAXYBRIDGE_APP_STORE
import Foundation

enum AndroidGalleryError: Error, LocalizedError, Equatable {
    case permissionRequired
    case malformedManifest
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Allow Galaxy Bridge to access photos and videos on the phone, then refresh."
        case .malformedManifest:
            "The phone returned an invalid gallery response."
        case let .unavailable(reason):
            reason
        }
    }
}

struct AndroidGalleryItem: Identifiable, Equatable, Sendable {
    let mediaID: Int64
    let name: String
    let mime: String
    let dateAdded: Date
    let width: Int
    let height: Int
    let size: Int64
    let kind: String
    let thumbnailData: Data?

    var id: Int64 { mediaID }
    var isVideo: Bool { kind == "video" }
}

struct AndroidGalleryPage: Sendable {
    let items: [AndroidGalleryItem]
    let nextOffset: Int
    let hasMore: Bool
}

struct AndroidGalleryEnhancedClient: Sendable {
    let adb: ADBClient

    func loadPage(serial: String, offset: Int, limit: Int = 96) throws -> AndroidGalleryPage {
        let requestID = Self.requestID()
        let remote = try adb.exportGalleryPage(serial: serial, requestID: requestID, offset: offset, limit: limit)
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("GalaxyBridge-GalleryPage-\(requestID)", isDirectory: true)
        defer {
            try? adb.removeGalleryExport(serial: serial, remotePath: remote)
            try? FileManager.default.removeItem(at: local)
        }
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try adb.pull(serial: serial, remotePath: "\(remote)/.", localURL: local)
        let data = try Data(contentsOf: local.appendingPathComponent("manifest.json"), options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let manifest = try decoder.decode(PageManifest.self, from: data)
        guard manifest.version == 1 else { throw AndroidGalleryError.malformedManifest }
        guard manifest.permission != "required" else { throw AndroidGalleryError.permissionRequired }
        let items = manifest.items.map { item in
            AndroidGalleryItem(
                mediaID: item.id,
                name: item.name,
                mime: item.mime,
                dateAdded: Date(timeIntervalSince1970: TimeInterval(item.dateAdded)),
                width: item.width,
                height: item.height,
                size: item.size,
                kind: item.kind,
                thumbnailData: item.thumbnail.flatMap {
                    try? Data(contentsOf: local.appendingPathComponent($0), options: [.mappedIfSafe])
                }
            )
        }
        return AndroidGalleryPage(items: items, nextOffset: offset + items.count, hasMore: manifest.hasMore)
    }

    func exportOriginal(serial: String, mediaID: Int64) throws -> URL {
        let requestID = Self.requestID()
        let remote = try adb.exportGalleryMedia(serial: serial, requestID: requestID, mediaID: mediaID)
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("GalaxyBridge-GalleryOpen", isDirectory: true)
            .appendingPathComponent(requestID, isDirectory: true)
        defer { try? adb.removeGalleryExport(serial: serial, remotePath: remote) }
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try adb.pull(serial: serial, remotePath: "\(remote)/.", localURL: local)
        let data = try Data(contentsOf: local.appendingPathComponent("manifest.json"), options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let manifest = try decoder.decode(MediaManifest.self, from: data)
        guard manifest.version == 1 else { throw AndroidGalleryError.malformedManifest }
        guard manifest.permission != "required" else { throw AndroidGalleryError.permissionRequired }
        if let error = manifest.error { throw AndroidGalleryError.unavailable(error) }
        guard let file = manifest.file, Self.safeRelativeName(file) else {
            throw AndroidGalleryError.malformedManifest
        }
        return local.appendingPathComponent(file)
    }

    func requestPermission(serial: String) throws {
        try adb.requestGalleryPermission(serial: serial)
    }

    private static func requestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func safeRelativeName(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 240 && !value.contains("/") && !value.contains("\\") &&
            !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    private struct PageManifest: Decodable {
        let version: Int
        let permission: String
        let offset: Int
        let hasMore: Bool
        let items: [ItemManifest]
    }

    private struct ItemManifest: Decodable {
        let id: Int64
        let name: String
        let mime: String
        let dateAdded: Int64
        let width: Int
        let height: Int
        let size: Int64
        let kind: String
        let thumbnail: String?
    }

    private struct MediaManifest: Decodable {
        let version: Int
        let permission: String?
        let file: String?
        let mime: String?
        let error: String?
    }
}
#endif
