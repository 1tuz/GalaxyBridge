import AppKit
import GalaxyBridgeCore
import SwiftUI

struct GalleryPanel: View {
    let device: DeviceRow

#if GALAXYBRIDGE_APP_STORE
    var body: some View {
        ContentUnavailableView(
            "Gallery",
            systemImage: "photo.on.rectangle.angled",
            description: Text("The direct Galaxy Bridge connection is required to browse the phone gallery.")
        )
    }
#else
    @EnvironmentObject private var model: AppModel
    @State private var items: [AndroidGalleryItem] = []
    @State private var nextOffset = 0
    @State private var hasMore = true
    @State private var loading = false
    @State private var permissionRequired = false
    @State private var errorText: String?
    @State private var openingID: Int64?

    private let columns = [GridItem(.adaptive(minimum: 132, maximum: 190), spacing: 12)]

    private var receivedImages: [IncomingFileRow] {
        model.incomingFilesByDevice[device.id, default: []].filter { row in
            !row.active &&
                !row.publishedName.isEmpty &&
                GalleryReceivedPresentation.isImageFile(name: row.publishedName.isEmpty ? row.name : row.publishedName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Gallery").font(.headline)
                    Text(
                        device.adbSerial == nil
                            ? String(localized: "Photos received from your phone")
                            : String(localized: "Photos and videos on your phone")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if permissionRequired {
                    Button("Allow on phone") { requestPermission() }
                }
                Button("Refresh") { Task { await reload() } }
                    .disabled(loading || device.adbSerial == nil)
            }
            .padding(16)
            Divider()

            galleryBody
        }
        .task(id: device.adbSerial) { await reload() }
    }

    @ViewBuilder
    private var galleryBody: some View {
        if device.adbSerial == nil {
            if GalleryReceivedPresentation.shouldShowReceivedFallback(
                adbSerial: device.adbSerial,
                receivedImageCount: receivedImages.count
            ) {
                receivedGrid
            } else {
                ContentUnavailableView(
                    "Gallery",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Connect the phone through USB or Wireless ADB to browse its gallery. Photos you send still appear here after transfer.")
                )
            }
        } else if permissionRequired && items.isEmpty {
            ContentUnavailableView {
                Label("Photo access required", systemImage: "photo.badge.exclamationmark")
            } description: {
                Text("Allow full photo and video access on the phone, then refresh.")
            } actions: {
                Button("Allow on phone") { requestPermission() }
                    .buttonStyle(.borderedProminent)
            }
        } else if items.isEmpty && loading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty, let errorText {
            ContentUnavailableView {
                Label("Gallery unavailable", systemImage: "photo.badge.exclamationmark")
            } description: {
                Text(errorText)
            } actions: {
                Button("Refresh") { Task { await reload() } }
            }
        } else if items.isEmpty {
            if !receivedImages.isEmpty {
                receivedGrid
            } else {
                ContentUnavailableView(
                    "No photos or videos",
                    systemImage: "photo.on.rectangle.angled"
                )
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        GalleryCell(item: item, opening: openingID == item.id)
                            .onTapGesture(count: 2) { open(item) }
                            .contextMenu {
                                Button("Open") { open(item) }
                            }
                    }
                }
                .padding(16)
                if hasMore {
                    Button {
                        Task { await loadNextPage(reset: false) }
                    } label: {
                        if loading { ProgressView().controlSize(.small) }
                        else { Text("Load more") }
                    }
                    .disabled(loading)
                    .padding(.bottom, 18)
                }
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                }
            }
        }
    }

    private var receivedGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(receivedImages) { row in
                    ReceivedGalleryCell(row: row)
                        .onTapGesture(count: 2) { openReceived(row) }
                        .contextMenu {
                            Button("Open") { openReceived(row) }
                            Button("Show in Finder") { revealReceived(row) }
                        }
                }
            }
            .padding(16)
        }
    }

    @MainActor private func reload() async {
        guard device.adbSerial != nil else { return }
        items = []
        nextOffset = 0
        hasMore = true
        permissionRequired = false
        errorText = nil
        await loadNextPage(reset: true)
    }

    @MainActor private func loadNextPage(reset: Bool) async {
        guard !loading, hasMore, let serial = device.adbSerial else { return }
        loading = true
        defer { loading = false }
        do {
            let offset = reset ? 0 : nextOffset
            let client = AndroidGalleryEnhancedClient(adb: try ADBClient())
            let page = try await Task.detached(priority: .userInitiated) {
                try client.loadPage(serial: serial, offset: offset)
            }.value
            if reset { items = page.items } else { items.append(contentsOf: page.items) }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            permissionRequired = false
            errorText = nil
        } catch AndroidGalleryError.permissionRequired {
            permissionRequired = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func requestPermission() {
        guard let serial = device.adbSerial else { return }
        Task {
            do {
                let client = AndroidGalleryEnhancedClient(adb: try ADBClient())
                try await Task.detached(priority: .userInitiated) {
                    try client.requestPermission(serial: serial)
                }.value
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func open(_ item: AndroidGalleryItem) {
        guard openingID == nil, let serial = device.adbSerial else { return }
        openingID = item.id
        Task {
            defer { openingID = nil }
            do {
                let client = AndroidGalleryEnhancedClient(adb: try ADBClient())
                let url = try await Task.detached(priority: .userInitiated) {
                    try client.exportOriginal(serial: serial, mediaID: item.mediaID)
                }.value
                NSWorkspace.shared.open(url)
            } catch AndroidGalleryError.permissionRequired {
                permissionRequired = true
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func downloadsURL(for row: IncomingFileRow) -> URL? {
        let name = row.publishedName.isEmpty ? row.name : row.publishedName
        guard !name.isEmpty, !name.contains("/") else { return nil }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }

    private func openReceived(_ row: IncomingFileRow) {
        guard let url = downloadsURL(for: row) else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealReceived(_ row: IncomingFileRow) {
        guard let url = downloadsURL(for: row) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private struct GalleryCell: View {
        let item: AndroidGalleryItem
        let opening: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary)
                    if let data = item.thumbnailData, let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: item.isVideo ? "video" : "photo").font(.system(size: 28))
                    }
                    if item.isVideo {
                        Image(systemName: "play.circle.fill").font(.system(size: 28)).symbolRenderingMode(.hierarchical)
                    }
                    if opening { ProgressView().controlSize(.small) }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(item.name).font(.caption).lineLimit(1)
                Text(item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private struct ReceivedGalleryCell: View {
        let row: IncomingFileRow

        var body: some View {
            let name = row.publishedName.isEmpty ? row.name : row.publishedName
            let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary)
                    if let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").font(.system(size: 28))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(name).font(.caption).lineLimit(1)
                Text("Received").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
#endif
}
