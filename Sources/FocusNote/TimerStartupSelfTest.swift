import AppKit

enum TimerStartupSelfTest {
    static func run(model: AppModel, check: (String, Bool) -> Void) {
        // Exercise the saved-frame branch that normal temporary-store tests skip.
        // Only a unique test key is written; the user's real saved frame is intact.
        let name = "focusnote-startup-regression-\(UUID().uuidString)"
        let key = "NSWindow Frame \(name)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        var expected = NSRect.zero
        do {
            let controller = TimerPanelController(timer: model.timer, frameAutosaveName: name)
            check("constructing a timer controller performs no AppKit window work", !controller.isPanelCreated)
            controller.show()
            check("first show safely creates and restores a timer after startup",
                  controller.isPanelCreated && controller.panel.isVisible)
            controller.panel.setContentSize(NSSize(width: 224, height: 256))
            controller.panel.saveFrame(usingName: name)
            expected = controller.panel.frame
            controller.panel.orderOut(nil)
            controller.panel.setFrameAutosaveName("")
        }
        let restored = TimerPanelController(timer: model.timer, frameAutosaveName: name)
        check("saved geometry does not force eager window creation", !restored.isPanelCreated)
        restored.show()
        check("a reopened timer restores its saved size without a graph crash",
              abs(restored.panel.frame.width - expected.width) < 1
                && abs(restored.panel.frame.height - expected.height) < 1)
        restored.panel.orderOut(nil)
        restored.panel.setFrameAutosaveName("")
    }
}
