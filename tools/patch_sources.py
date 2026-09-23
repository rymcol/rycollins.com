#!/usr/bin/env python3
"""Patches throwaway copies of the app sources for rendering site screenshots.

    patch_sources.py xcv <copy of xcv>
    patch_sources.py percolate <dir with copies of CupScene.swift and CupLayer.swift>

Every replacement must match exactly once, so a change in the apps fails loudly
instead of producing a quietly wrong screenshot.
"""
import sys
from pathlib import Path

XCV = {
    # Read history from XCV_STORE_DIR (seeded demo data), never the real store.
    "Sources/xcv/Clipboard/ClipboardStore.swift": [(
        '        baseDir = support.appendingPathComponent("xcv", isDirectory: true)\n',
        '        baseDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["XCV_STORE_DIR"]!, isDirectory: true)\n'
        '        _ = support\n',
    )],
    # Never watch the live pasteboard, never register the global hotkey.
    "Sources/xcv/App/AppDelegate.swift": [
        ('        monitor.start()\n', ''),
        ('        applyHotKey()\n\n        // First run', '\n        // First run'),
    ],
    # ImageRenderer never runs .task, so take thumbnails the live panel already cached.
    "Sources/xcv/UI/ClipCard.swift": [(
        '            if let image {\n                Image(nsImage: image)',
        '            if let image = image ?? store.cachedThumbnail(for: item) {\n                Image(nsImage: image)',
    )],
    # On an XDR display the render comes back as 16-bit BT.2100 PQ; flatten to 8-bit sRGB for the web.
    "Sources/xcv/Notch/NotchController.swift": [(
        '        guard let cg = renderer.cgImage else { NSLog("snapshot: render failed"); return }\n',
        '        guard let hdr = renderer.cgImage else { NSLog("snapshot: render failed"); return }\n'
        '        let ctx = CGContext(data: nil, width: hdr.width, height: hdr.height, bitsPerComponent: 8, bytesPerRow: 0,\n'
        '                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!\n'
        '        ctx.draw(hdr, in: CGRect(x: 0, y: 0, width: hdr.width, height: hdr.height))\n'
        '        let cg = ctx.makeImage()!\n',
    )],
}

PERCOLATE = {
    # Expose a single frame, with separate steam clocks so a rendered loop can close seamlessly.
    "CupLayer.swift": [
        ('    private struct Frame {', '    struct Frame {'),
        ('    private static func frame(for pose: CupScene.Pose) -> Frame {', '    static func frame(for pose: CupScene.Pose) -> Frame {'),
        ('    private func show(_ frame: Frame, steamTime: Double) {',
         '    func show(_ frame: Frame, steamTime: Double) { show(frame, waveTime: steamTime, breathTime: steamTime) }\n'
         '    func show(_ frame: Frame, waveTime: Double, breathTime: Double) {'),
        ('            wisp.path = Self.wispPath(index, time: steamTime)\n'
         '            wisp.opacity = Float(Self.wispOpacity(index, time: steamTime))',
         '            wisp.path = Self.wispPath(index, time: waveTime)\n'
         '            wisp.opacity = Float(Self.wispOpacity(index, time: breathTime))'),
        ('    private static let wavePeriod', '    static let wavePeriod'),
        ('    private static let breathPeriod', '    static let breathPeriod'),
    ],
}


def apply(root: Path, patches: dict) -> None:
    for rel, edits in patches.items():
        path = root / rel
        text = path.read_text()
        for old, new in edits:
            count = text.count(old)
            if count != 1:
                sys.exit(f"{rel}: expected one match, found {count}:\n{old}")
            text = text.replace(old, new)
        path.write_text(text)


if __name__ == "__main__":
    which, root = sys.argv[1], Path(sys.argv[2])
    apply(root, {"xcv": XCV, "percolate": PERCOLATE}[which])
