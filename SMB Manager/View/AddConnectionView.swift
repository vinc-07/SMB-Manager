import SwiftUI

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
