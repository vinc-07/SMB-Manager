import SwiftUI

// MARK: - 新增連線視窗
struct AddConnectionView: View {
    @ObservedObject var manager: SMBManager
    @State private var smbUrl: String = "smb://"
	// 讀取語系設定 ("zh-Hant" 或 "en")
	@AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
		
	// 建立一個方便內部呼叫的閉包，減少程式碼長度
	private func local(_ key: String) -> String {
		MenuLocalization.text(for: key, lang: selectedLanguage)
	}
    
    var body: some View {
        VStack(spacing: 20) {
            Text(local("enterURL"))
                .font(.headline)
            
            TextField("smb://server/share", text: $smbUrl)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 340)
            
            HStack {
                Button(local("cancel")) {
                    NSApp.keyWindow?.close()
                }
                Spacer()
                Button(local("connect")) {
                    manager.connect(urlString: smbUrl)
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!smbUrl.hasPrefix("smb://") || smbUrl.count < 7)
            }
            .frame(width: 340)
        }
        .padding()
    }
}

// MARK: - 偏好設定視窗
struct PreferencesView: View {
    @ObservedObject var manager: SMBManager
	// 讀取語系設定 ("zh-Hant" 或 "en")
	@AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
		
	// 建立一個方便內部呼叫的閉包，減少程式碼長度
	private func local(_ key: String) -> String {
		MenuLocalization.text(for: key, lang: selectedLanguage)
	}
    
    // 新增常用項目暫存
    @State private var newDisplayName: String = ""
    @State private var newUrl: String = "smb://"
    
    // 編輯暫存
    @State private var editingItem: SMBItem?
    
    var body: some View {
        TabView {
            // 頁籤 1：語言設定
            VStack(alignment: .leading, spacing: 20) {
                Text(local("language"))
                    .font(.headline)
                
                Picker("", selection: $selectedLanguage) {
                    Text("繁體中文").tag("zh-Hant")
                    Text("English").tag("en")
                }
                .pickerStyle(RadioGroupPickerStyle())
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label(local("general"), systemImage: "gearshape")
            }
            
            // 頁籤 2：常用清單維護
            VStack {
                // 清單列表
                List {
                    ForEach(manager.favoriteList) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.displayName).font(.bold(.body)())
                                Text(item.url).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Button(local("edit")) {
                                editingItem = item
                                newDisplayName = item.displayName
                                newUrl = item.url
                            }
                            Button(local("del")) {
                                if let index = manager.favoriteList.firstIndex(of: item) {
                                    manager.favoriteList.remove(at: index)
                                }
                            }
                        }
                    }
                }
                .frame(height: 180)
                
                Divider()
                
                // 新增 / 修改區塊
                VStack(alignment: .leading, spacing: 8) {
                    Text(editingItem == nil ? 
                         (local("addFavorite")) :
                         (local("editFavorite")))
                        .font(.subheadline).bold()
                    
                    HStack {
						TextField(local("displayName"), text: $newDisplayName)
                        TextField("smb://...", text: $newUrl)
                    }
                    
                    HStack {
                        if editingItem != nil {
                            Button(local("cancel")) {
                                clearInput()
                            }
                        }
                        Spacer()
                        Button(local("save")) {
                            if let editing = editingItem, let index = manager.favoriteList.firstIndex(of: editing) {
                                // 修改
                                manager.favoriteList[index] = SMBItem(id: editing.id, displayName: newDisplayName, url: newUrl)
                            } else {
                                // 新增
                                let newItem = SMBItem(displayName: newDisplayName, url: newUrl)
                                manager.favoriteList.append(newItem)
                            }
                            clearInput()
                        }
                        // 限制：Display Name 必須輸入才可儲存
                        .disabled(newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !newUrl.hasPrefix("smb://"))
                    }
                }
                .padding(.horizontal)
            }
            .tabItem {
                Label(local("favorites"), systemImage: "star")
            }
        }
        .padding()
    }
    
    private func clearInput() {
        editingItem = nil
        newDisplayName = ""
        newUrl = "smb://"
    }
}
