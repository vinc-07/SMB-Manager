//
//  LanguageKey.swift
//  SMB Manager
//
//  Created by Vincent Lu on 2026/6/13.
//


import Foundation

// 定義語系金鑰，方便程式碼讀取，避免打錯字
enum LanguageKey: String {
    case zhHant = "zh-Hant"
    case en = "en"
}

// 統一管理的語系參數表 (Localization Dictionary)
struct MenuLocalization {
    static let table: [String: [String: String]] = [
        "zh-Hant": [
            "addConnection": "新增連線...",
            "favorites": "常用清單",
            "noFavorites": "(無常用項目)",
            "currentConnections": "當前連線清單",
            "noConnections": "(無其他連線)",
            "preferences": "偏好設定...",
            "quit": "退出",
			"enterURL": "輸入 SMB 連線網址",
			"connect": "連線",
			"cancel": "取消",
			"language": "介面語言",
			"general": "一般",
			"edit": "編輯",
			"del": "刪除",
			"addFavorite": "新增常用項目",
			"editFavorite": "修改常用項目",
			"displayName": "顯示名稱(必填)",
			"save": "儲存"
        ],
        "en": [
            "addConnection": "Add Connection...",
            "favorites": "Favorites",
            "noFavorites": "(No Favorites)",
            "currentConnections": "Current Connections",
            "noConnections": "(No Other Connections)",
            "preferences": "Preferences...",
            "quit": "Quit",
			"enterURL": "Enter SMB Connection URL",
			"connect": "Connect",
			"cancel": "Cancel",
			"language": "Interface Language",
			"general": "General",
			"edit": "Edit",
			"del": "Delete",
			"addFavorite": "Add Favorite",
			"editFavorite": "Edit Favorite",
			"displayName": "Display Name (required)",
			"save": "Save"

        ]
    ]
    
    // 安全讀取文字的輔助函式，若找不到則回傳空字串
    static func text(for key: String, lang: String) -> String {
        return table[lang]?[key] ?? ""
    }
}
