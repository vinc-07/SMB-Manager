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
	// 變更：改為儲存「標準化且不含帳密」的遠端完整 URL 字串，比對更精準
	@Published var connectedVolumes: [String] = []
	
	// 用來管理非同步工作，避免重複執行
	private var updateTask: Task<Void, Never>?
	
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
	
	// 修正：加入 deinit 確保移除監聽器，避免記憶體洩漏
	deinit {
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}
	
	@objc private func volumeDidChange() {
		updateConnectedVolumes()
	}
	
	// 修正：改為非同步處理（I/O 密集型操作），避免卡死主執行緒 (UI Live Lock)
	func updateConnectedVolumes() {
		updateTask?.cancel() // 取消上一次尚未完成的檢查
		
		updateTask = Task {
			let keys: [URLResourceKey] = [.volumeURLKey, .volumeURLForRemountingKey]
			guard let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return }
			
			var smbMounts: [String] = []
			
			for url in mounts {
				// 檢查 Task 是否已被取消
				if Task.isCancelled { return }
				
				do {
					let values = try url.resourceValues(forKeys: [.volumeURLForRemountingKey])
					// 確保這是 SMB 網路磁碟機
					if let remountURL = values.volumeURLForRemounting, remountURL.scheme == "smb" {
						// 儲存經過安全處理（抹除密碼）的完整遠端 URL，例如 smb://nas.local/Public
						let safeURL = sanitizeURL(remountURL.absoluteString)
						smbMounts.append(safeURL)
					}
				} catch {
					// 忽略讀取失敗的本機硬碟或其他系統專用掛載點
					continue
				}
			}
			
			// 回到主執行緒更新 UI 狀態
			await MainActor.run {
				self.connectedVolumes = smbMounts
			}
		}
	}
	
	// 呼叫 macOS 底層 SMB 連線
	func connect(urlString: String) {
		// 修正：針對可能含有中文或特殊字元的 URL 進行百分比編碼，避免 URL(string:) 回傳 nil
		guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
			  let url = URL(string: encodedString),
			  url.scheme == "smb" else { return }
		
		// 使用 NSWorkspace 開啟 smb:// URL，系統會自動彈出原生連線驗證視窗
		NSWorkspace.shared.open(url)
	}
	
	// 斷開連線 (Unmount)
	// 修正：參數改為傳入要中斷的遠端 URL 或是本地路徑，不再硬編碼 "/Volumes/\(volumeName)"
	func disconnect(remoteURL: String) {
		let targetURL = sanitizeURL(remoteURL)
		
		Task {
			let keys: [URLResourceKey] = [.volumeURLKey, .volumeURLForRemountingKey]
			guard let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return }
			
			// 動態尋找系統中對應這個遠端 URL 的本地掛載點
			var localMountURL: URL? = nil
			for url in mounts {
				if let values = try? url.resourceValues(forKeys: [.volumeURLForRemountingKey]),
				   let remountURL = values.volumeURLForRemounting,
				   sanitizeURL(remountURL.absoluteString) == targetURL {
					localMountURL = url
					break
				}
			}
			
			// 如果找到了正確的本地掛載路徑，則執行彈出
			if let urlToUnmount = localMountURL {
				do {
					try await NSWorkspace.shared.unmountAndEjectDevice(at: urlToUnmount)
					// 成功後，更新狀態
					self.updateConnectedVolumes()
				} catch {
					print("斷開連線失敗: \(error.localizedDescription)")
				}
			} else {
				print("找不到對應的掛載點，無法斷開連線: \(remoteURL)")
			}
		}
	}
	
	// 修正：改用「完整且乾淨的 URL」進行精準比對，徹底解決同名資料夾（例如都叫 Public）或 macOS 自動改名（Public-1）的誤判問題
	func isConnected(url: String) -> Bool {
		let cleanURL = sanitizeURL(url)
		return connectedVolumes.contains(cleanURL)
	}
	
	func getCleanURL(_ urlString: String) -> String {
		return sanitizeURL(urlString)
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
		let keys: [URLResourceKey] = [.volumeURLKey, .volumeLocalizedNameKey, .volumeURLForRemountingKey]
		guard let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) else { return "smb://\(volumeName)" }
		
		// 修正：不硬編碼路徑，而是透過本地名稱（Volume Localized Name）動態查找
		for url in mounts {
			if let values = try? url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeURLForRemountingKey]),
			   values.volumeLocalizedName == volumeName,
			   let remountURL = values.volumeURLForRemounting {
				return sanitizeURL(remountURL.absoluteString)
			}
		}
		
		// 如果系統 API 沒抓到，嘗試從常用清單中比對
		if let matchingFav = favoriteList.first(where: { URL(string: $0.url)?.lastPathComponent == volumeName }) {
			return sanitizeURL(matchingFav.url)
		}
		
		return "\(volumeName)"
	}

	// 核心過濾器：移除 URL 中的帳號與密碼 (例如 smb://user:pass@server -> smb://server)
	private func sanitizeURL(_ urlString: String) -> String {
		// 修正：先嘗試解碼，避免重複編碼或格式錯亂，接著再抹除隱私資訊
		guard let decodedString = urlString.removingPercentEncoding,
			  var components = URLComponents(string: decodedString) else { return urlString }
		
		components.user = nil
		components.password = nil
		
		return components.string ?? urlString
	}
}
