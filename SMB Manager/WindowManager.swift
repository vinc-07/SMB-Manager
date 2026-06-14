import SwiftUI
import AppKit

class WindowManager {
    static let shared = WindowManager()
    
    private var addConnectionWindowController: NSWindowController?
    private var preferencesWindowController: NSWindowController?
	@AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
		
	// 建立一個方便內部呼叫的閉包，減少程式碼長度
	private func local(_ key: String) -> String {
		MenuLocalization.text(for: key, lang: selectedLanguage)
	}
    
    func showAddConnection(manager: SMBManager) {
        if addConnectionWindowController == nil {
            let contentView = AddConnectionView(manager: manager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.center()
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            addConnectionWindowController = NSWindowController(window: window)
        }
        
        addConnectionWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // 關鍵：強制讓 App 取得焦點移至最前端
    }
    
    func showPreferences(manager: SMBManager) {
        if preferencesWindowController == nil {
            let contentView = PreferencesView(manager: manager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.center()
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            preferencesWindowController = NSWindowController(window: window)
        }
        
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // 關鍵：強制讓 App 取得焦點移至最前端
    }
}
