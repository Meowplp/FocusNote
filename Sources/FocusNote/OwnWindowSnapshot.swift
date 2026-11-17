import AppKit

/// Draw only views owned by this process. No WindowServer capture, screen or
/// audio recording APIs, subprocesses, or privacy grants are involved.
enum OwnWindowSnapshot {
    enum RenderError: Error {
        case missingContent, allocationFailed, encodingFailed
    }

    static func png(window: NSWindow) throws -> Data {
        guard let view = window.contentView?.superview ?? window.contentView else {
            throw RenderError.missingContent
        }
        view.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw RenderError.allocationFailed
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.encodingFailed
        }
        return data
    }
}
