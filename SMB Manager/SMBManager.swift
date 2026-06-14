import Foundation
import AppKit
import Combine

struct SMBItem: Identifiable, Codable, Equatable {
	var id = UUID()
	var displayName: String
	var url: String
}

class SMBManager: ObservableObject {
	@Published var favoriteList: [SMBItem] = [] {
		didSet { saveFavorites() }
	}
	@Published var connectedVolumes: [String] = [] // 儲存當前掛載的名稱
	
	init() {
		loadFavorites()
		updateConnectedVolumes()
		
		// 監聽系統掛載通知，自動更新連線狀態
		NSWorkspace.shared.notificationCenter.addObserver(
			self,
			selector: #selector(volumeDidChange),
			name: NSWorkspace.didMountNotification,
			object: nil
		)
		NSWorkspace.shared.notificationCenter.addObserver(
			self,
			selector: #selector(volumeDidChange),
			name: NSWorkspace.didUnmountNotification,
			object: nil
		)
	}
	
	@objc private func volumeDidChange() {
		DispatchQueue.main.async {
			self.updateConnectedVolumes()
		}
	}
	
	// 檢查系統當前已連線的 SMB
	func updateConnectedVolumes() {
		let keys: [URLResourceKey] = [.volumeURLKey, .volumeLocalizedNameKey]
		guard let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return }
		
		var smbMounts: [String] = []
		for url in mounts {
			// 透過檢查 URL 模式或系統掛載路徑（通常在 /Volumes/）
			// 這裡簡化示範：獲取資料夾名稱
			if url.path.hasPrefix("/Volumes/") && url.path != "/Volumes" {
				smbMounts.append(url.lastPathComponent)
			}
		}
		self.connectedVolumes = smbMounts
	}
	
	// 呼叫 macOS 底層 SMB 連線
	func connect(urlString: String) {
		guard let url = URL(string: urlString), url.scheme == "smb" else { return }
		// 使用 NSWorkspace 開啟 smb:// URL，系統會自動彈出原生連線驗證視窗
		NSWorkspace.shared.open(url)
	}
	
	// 斷開連線 (Unmount)
	func disconnect(volumeName: String) {
		let volumePath = "/Volumes/\(volumeName)"
		let url = URL(fileURLWithPath: volumePath)
		
		// 使用 Task 包裹非同步呼叫
		Task {
			do {
				try await NSWorkspace.shared.unmountAndEjectDevice(at: url)
				// 成功後，回到主執行緒更新狀態
				await MainActor.run {
					self.updateConnectedVolumes()
				}
			} catch {
				print("斷開連線失敗: \(error.localizedDescription)")
			}
		}
	}
	
	// 檢查特定 URL 是否已連線 (依據最後的資料夾名稱比對)
	func isConnected(url: String) -> Bool {
		guard let components = URL(string: url), let lastComponent = components.pathComponents.last else { return false }
		return connectedVolumes.contains(lastComponent)
	}
	
	// MARK: - UserDefaults 儲存
	private func saveFavorites() {
		if let encoded = try? JSONEncoder().encode(favoriteList) {
			UserDefaults.standard.set(encoded, forKey: "SMB_Favorites")
		}
	}
	
	private func loadFavorites() {
		if let data = UserDefaults.standard.data(forKey: "SMB_Favorites"),
		   let decoded = try? JSONDecoder().decode([SMBItem].self, from: data) {
			self.favoriteList = decoded
		}
	}
	
	// 獲取掛載點的實際遠端連線 URL，並移除帳號密碼
	func getSafeRemoteURL(for volumeName: String) -> String {
		let volumePath = "/Volumes/\(volumeName)"
		let url = URL(fileURLWithPath: volumePath)
		
		do {
			// 取得系統掛載的資源屬性
			let values = try url.resourceValues(forKeys: [.volumeURLForRemountingKey])
			if let remountURL = values.volumeURLForRemounting {
				return sanitizeURL(remountURL.absoluteString)
			}
		} catch {
			print("無法取得 \(volumeName) 的遠端 URL: \(error.localizedDescription)")
		}
		
		// 如果系統 API 沒抓到，嘗試從常用清單中比對，或回傳預設提示
		if let matchingFav = favoriteList.first(where: { URL(string: $0.url)?.pathComponents.last == volumeName }) {
			return sanitizeURL(matchingFav.url)
		}
		
		return "smb://\(volumeName)"
	}

	// 核心過濾器：移除 URL 中的帳號與密碼 (例如 smb://user:pass@server -> smb://server)
	private func sanitizeURL(_ urlString: String) -> String {
		guard var components = URLComponents(string: urlString) else { return urlString }
		
		// 將使用者名稱與密碼設為 nil
		components.user = nil
		components.password = nil
		
		return components.string ?? urlString
	}
}
