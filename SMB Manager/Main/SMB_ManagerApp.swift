import SwiftUI

@main
struct SMB_ManagerApp: App {
	@StateObject private var manager = SMBManager()
	
	// 讀取語系設定 ("zh-Hant" 或 "en")
	@AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
		
	// 建立一個方便內部呼叫的閉包，減少程式碼長度
	private func local(_ key: String) -> String {
		MenuLocalization.text(for: key, lang: selectedLanguage)
	}
	
	var body: some Scene {
		MenuBarExtra("SMB Manager", systemImage: "externaldrive.connected.to.line.below") {
			// 使用 Group 包覆選單內容，並將 .labelStyle 套用在 Group 上
			Group {
				// ==========================================
				// 功能 1：新增連線
				// ==========================================
				Button(action: {
					WindowManager.shared.showAddConnection(manager: manager)
				}) {
					Label(local("addConnection"), systemImage: "plus.circle")
				}
				
				Divider()
				
				// ==========================================
				// 功能 2：常用清單 (直接呈現於第一層)
				// ==========================================
				Text(local("favorites"))
					.font(.headline)
				
				if manager.favoriteList.isEmpty {
					Button(local("noFavorites")) {}
						.disabled(true)
				} else {
					ForEach(manager.favoriteList) { item in
						let connected = manager.isConnected(url: item.url)
						Button(action: {
							if connected {
								manager.disconnect(remoteURL: item.url)
							} else {
								manager.connect(urlString: item.url)
							}
						}) {
							Label(
								title: { Text(item.displayName) },
								icon: {
									Image(systemName: connected ? "circle.fill" : "circle")
								}
							)
						}
					}
				}
				
				Divider()
				
				// ==========================================
				// 功能 3：當前連線清單 (直接呈現於第一層，雙行顯示，隱藏帳密)
				// ==========================================
				Text(local("currentConnections"))
					.font(.headline)

				let filteredConnections = manager.connectedVolumes.filter { volURL in
					!manager.favoriteList.contains { fav in
						manager.getCleanURL(fav.url) == volURL
					}
				}

				if filteredConnections.isEmpty {
					Button(local("noConnections")) {}
						.disabled(true)
				} else {
					ForEach(filteredConnections, id: \.self) { volName in
						let safeURL = manager.getSafeRemoteURL(for: volName)
						let displayName = volName.split(separator: "/").last.map(String.init) ?? volName
						
						// 第一行：主要按鈕，顯示名稱與退出的圖示，點擊觸發斷開連線
						Button(action: {
							manager.disconnect(remoteURL: safeURL)
						}) {
							Label(displayName, systemImage: "multiply.circle")
						}
						
						// 第二行：實際 URL 資訊
						Button(action: {}) {
							Text("\(safeURL)")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						.disabled(true)
					}
				}
				
				Divider()
				
				// ==========================================
				// 功能 4：偏好設定 & 退出
				// ==========================================
				Button(action: {
					WindowManager.shared.showPreferences(manager: manager)
				}) {
					Label(local("preferences"), systemImage: "gearshape")
				}
				
				Button(action: {
					NSApp.terminate(nil)
				}) {
					Label(local("quit"), systemImage: "power")
				}
			}
			.labelStyle(.titleAndIcon)
		}
	}
}
