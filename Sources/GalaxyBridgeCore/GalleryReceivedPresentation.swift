import Foundation

/// Decides what the Mac Gallery panel should show when phone MediaStore
/// browse is unavailable (companion-LAN without ADB) but files already arrived.
public enum GalleryReceivedPresentation: Sendable {
    public static func imageExtensions() -> Set<String> {
        ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
    }

    public static func isImageFile(name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return imageExtensions().contains(ext)
    }

    /// Prefer live phone browse when ADB is bound; otherwise surface received
    /// image transfers so a successful send is visible in Gallery.
    public static func shouldShowReceivedFallback(
        adbSerial: String?,
        receivedImageCount: Int
    ) -> Bool {
        adbSerial == nil && receivedImageCount > 0
    }
}
