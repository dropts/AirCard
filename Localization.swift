import Foundation
import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// Shown in the language picker. Never translated on purpose: a language is
    /// always written in its own tongue.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    /// Compact label for the header control.
    var shortName: String {
        switch self {
        case .english: return "EN"
        case .simplifiedChinese: return "中"
        }
    }
}

// MARK: - Localization Manager

/// Holds the active interface language. Views observe this object so switching
/// languages re-renders them immediately, without restarting the app.
///
/// Lookup keys are the English source strings, so English needs no table and a
/// missing translation degrades to English instead of showing an empty label.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let defaultsKey = "mak5er.aircard.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let lang = AppLanguage(rawValue: stored) {
            self.language = lang
            return
        }
        // First run: follow the system's preferred language when it is one we ship.
        let preferred = Locale.preferredLanguages.first ?? "en"
        self.language = preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    func string(_ key: String) -> String {
        guard language != .english else { return key }
        return Self.simplifiedChinese[key] ?? key
    }
}

/// Translate `key` into the active language.
@inline(__always) func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

/// Same as `L`, but returns a `LocalizedStringKey` so SwiftUI still renders
/// inline markdown (`**bold**`) inside `Text`.
@inline(__always) func LK(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(L(key))
}

// MARK: - Simplified Chinese Table

extension LocalizationManager {
    static let simplifiedChinese: [String: String] = [
        // MARK: Wallet card tile
        "Remove skin": "移除皮肤",
        "Change Skin": "更换皮肤",
        "Drop image here": "拖放图片到此处",
        "Assign Card Skin": "分配卡片皮肤",
        "Click to browse or drag image": "点击浏览或拖入图片",
        "Include in flash": "参与刷入",
        "Card #%d": "卡片 #%d",
        "Copied!": "已复制！",
        "Copy full hash": "复制完整哈希",
        "Skin assigned and ready": "皮肤已分配，准备就绪",
        "Remove from list": "从列表中移除",

        // MARK: Header / global chrome
        "Wallet Cards & Passcode Themes": "钱包卡片与密码主题",
        "No iPhone (USB)": "未连接 iPhone",
        "Refresh device connection": "刷新设备连接",
        "Credits": "致谢",
        "Interface language": "界面语言",

        // MARK: Wallet toolbar
        "Stop Scanning": "停止扫描",
        "Scan Cards": "扫描卡片",
        "Add Manually": "手动添加",
        "Set Skin for All...": "为全部设置皮肤…",
        "Assign one skin to all selected cards": "为所有选中的卡片分配同一皮肤",
        "Select All": "全选",
        "Deselect All": "取消全选",
        "Clear All": "清空全部",

        // MARK: Live scanner banner
        "Live Scanner Active": "实时扫描已开启",
        "Double-click Side button (Apple Pay), pass Face ID, then tap your card.": "双击侧边按钮（Apple Pay），通过 Face ID，然后点击你的卡片。",
        "Done": "完成",

        // MARK: Empty state
        "No Cards Detected Yet": "尚未检测到卡片",
        "Click **Scan Cards** in the toolbar above.": "点击上方工具栏中的**扫描卡片**。",
        "On your iPhone, **double-click the Side button** (Apple Pay), authenticate with **Face ID**, and **tap your card**.": "在你的 iPhone 上**双击侧边按钮**（Apple Pay），通过 **Face ID** 验证，然后**点击你的卡片**。",
        "Your card will be detected immediately!": "你的卡片会立即被检测到！",
        "Start Scanning": "开始扫描",
        "Add Hashes Manually": "手动添加哈希",

        // MARK: Passcode toolbar
        "Choose .passthm File...": "选择 .passthm 文件…",
        "Choose Poster...": "选择海报…",
        "Change Poster...": "更换海报…",
        "Export .passthm...": "导出 .passthm…",
        "Target:": "目标：",
        "Universal (All 8, 9, 10)": "通用（8、9、10 全版本）",
        "Clear Theme": "清除主题",

        // MARK: Apply theme
        "Lock Screen Keypad Preview": "锁屏键盘预览",
        "Custom Theme Loaded": "自定义主题已加载",
        "Passcode Theme File": "密码主题文件",
        "%d artwork assets loaded · Ready to flash to iPhone": "已加载 %d 个素材 · 可刷入 iPhone",
        "Edit in Creator": "在创作器中编辑",
        "Change...": "更换…",
        "Clear": "清除",
        "Drop .passthm file here": "将 .passthm 文件拖到此处",
        "Supports .passthm, .passtheme, or .zip packages from Cowabunga or Nugget": "支持来自 Cowabunga 或 Nugget 的 .passthm、.passtheme 或 .zip 包",
        "Choose File...": "选择文件…",

        // MARK: Theme creator
        "Interactive iPhone Lock Screen Preview": "iPhone 锁屏交互预览",
        "Drag dialer to pan · Use slider to zoom": "拖动键盘平移 · 使用滑块缩放",
        "Poster Artwork": "海报素材",
        "Artwork Loaded": "素材已加载",
        "Remove": "移除",
        "Drop poster or wallpaper here": "将海报或壁纸拖到此处",
        "Choose Image...": "选择图片…",
        "Slicing Style": "切片样式",
        "Seamless Poster": "无缝海报",
        "Circle Buttons": "圆形按键",
        "Artwork is clipped into individual circular button icons.": "素材将被裁剪为独立的圆形按键图标。",
        "Seamless artwork spans across dialer keys without circular cuts (Adobe Dog style).": "无缝素材横跨整个键盘，不做圆形裁剪（Adobe Dog 风格）。",
        "Zoom & Framing": "缩放与取景",
        "Reset Position": "重置位置",
        "Zoom": "缩放",
        "Drag anywhere on the dialer preview to reposition": "在键盘预览的任意位置拖动以重新定位",
        "Individual Keys": "单独按键",
        "Deselect Key %@": "取消选择按键 %@",
        "Key %@ Framing": "按键 %@ 取景",
        "Reset": "重置",
        "Drag Key %@ on dialer preview to reposition": "在键盘预览上拖动按键 %@ 以重新定位",
        "Change Image...": "更换图片…",
        "Click any key on the dialer to select it, pan the image, adjust zoom, or drop files.": "点击键盘上的任意按键进行选择，可平移图片、调整缩放或直接拖入文件。",
        "%d of 10 keys configured": "已配置 %d/10 个按键",
        "Fill from Poster": "从海报填充",
        "Clear All Keys": "清空所有按键",

        // MARK: Per-key context menu
        "Change Key %@...": "更换按键 %@…",
        "Reset Position & Zoom": "重置位置与缩放",
        "Clear Key %@": "清除按键 %@",

        // MARK: Lock screen mockup (mirrors the iPhone's own wording)
        "Enter Passcode": "输入密码",
        "Emergency": "紧急",
        "Cancel": "取消",

        // MARK: Flash target card
        "Flash & Language Target": "刷入与语言目标",
        "Auto-detect": "自动检测",
        "Reset to iPhone's detected language and font style": "重置为 iPhone 检测到的语言与字体样式",
        "System Language:": "系统语言：",
        "Font Weight / Style:": "字重 / 样式：",
        "Universal mode flashes ~600 files for all languages & Bold text. Selecting a specific language (e.g. Ukrainian) speeds up flashing dramatically.": "通用模式会刷入约 600 个文件，覆盖所有语言与粗体文本。选择特定语言（例如乌克兰语）可显著加快刷入速度。",
        "Fast mode selected: only targets %1$@ with %2$@.": "已选择快速模式：仅针对 %1$@（%2$@）刷入。",

        // MARK: Activity log & bottom bar
        "Activity Log": "活动日志",
        "Log": "日志",
        "Flashing Passcode...": "正在刷入密码…",
        "Flash to iPhone": "刷入 iPhone",
        "Flash Passcode Theme": "刷入密码主题",
        "Flashing Cards...": "正在刷入卡片…",
        "Flash Skins (%d Cards)": "刷入皮肤（%d 张卡片）",
        "Flash Skins": "刷入皮肤",
        "By": "作者",
        "Theme Creator · %d of 10 keys configured · Target: %@": "主题创作器 · 已配置 %d/10 个按键 · 目标：%@",
        "Theme Creator · Import a poster or drop icons onto keys": "主题创作器 · 导入海报或将图标拖到按键上",
        "%d source assets loaded · Target: %@": "已加载 %d 个源素材 · 目标：%@",
        "No .passthm loaded · Select a theme package to flash": "未加载 .passthm · 请选择要刷入的主题包",
        "%1$d of %2$d cards selected · %3$d ready to flash": "已选择 %1$d/%2$d 张卡片 · %3$d 张可刷入",

        // MARK: Credits sheet
        "Apple Wallet Skins & Passcode Themes for iOS 18+": "适用于 iOS 18+ 的 Apple 钱包皮肤与密码主题",
        "Developer:": "开发者：",
        "Core Exploit:": "核心漏洞利用：",
        "Passcode Themes:": "密码主题：",
        ".passthm standard (Cowabunga / Nugget)": ".passthm 标准（Cowabunga / Nugget）",
        "Close": "关闭",

        // MARK: Add card hashes sheet
        "Add Card Hashes Manually": "手动添加卡片哈希",
        "Paste one or more card hashes (separated by spaces, commas, or newlines):": "粘贴一个或多个卡片哈希（以空格、逗号或换行分隔）：",
        "Add to List": "添加到列表",

        // MARK: Alerts
        "Success!": "成功！",
        "OK": "好",
        "Passcode theme successfully applied!\n\nLock your iPhone (or restart) to see your new passcode keypad.": "密码主题应用成功！\n\n锁定 iPhone（或重启）即可看到新的密码键盘。",
        "Skins successfully applied to all selected cards!\n\nPlease force-close the Wallet app on your iPhone (or reboot) to see your new designs.": "皮肤已成功应用到所有选中的卡片！\n\n请在 iPhone 上强制关闭钱包应用（或重启）以查看新设计。",

        // MARK: Open / save panels
        "Choose a custom skin for card %@...": "为卡片 %@ 选择自定义皮肤…",
        "Choose a skin to assign to all selected cards...": "选择要分配给所有选中卡片的皮肤…",
        "Choose a .passthm passcode theme package...": "选择一个 .passthm 密码主题包…",
        "Choose Poster Image": "选择海报图片",
        "Select a wallpaper or photo to slice for the passcode keypad...": "选择一张壁纸或照片，用于切片为密码键盘…",
        "Choose Icon for Key %@": "为按键 %@ 选择图标",
        "Select an icon or image for key %@...": "为按键 %@ 选择一个图标或图片…",
        "Save Passcode Theme": "保存密码主题",
        "Export": "导出",

        // MARK: Status & error messages
        "Ready": "就绪",
        "Checking connected devices...": "正在检查已连接的设备…",
        "Connected to %@": "已连接到 %@",
        "Device tools are missing from this build.": "此版本缺少设备工具。",
        "No iPhone found. Please connect via USB.": "未找到 iPhone，请通过 USB 连接。",
        "Device detection failed: %@": "设备检测失败：%@",
        "Double-click Side button, pass Face ID, then tap your card...": "双击侧边按钮，通过 Face ID，然后点击你的卡片…",
        "Could not start card scanning.": "无法启动卡片扫描。",
        "Card scanning ended. Check the log and reconnect the iPhone to retry.": "卡片扫描已结束。请查看日志并重新连接 iPhone 后重试。",
        "Card scanning failed. Check the log and retry.": "卡片扫描失败。请查看日志后重试。",
        "No iPhone connected.": "未连接 iPhone。",
        "Please assign a skin image to at least one selected card.": "请为至少一张选中的卡片分配皮肤图片。",
        "[%1$d/%2$d] Preparing skin for %3$@...": "正在为 %3$@ 准备皮肤 [%1$d/%2$d]…",
        "Failed to apply card skins.": "卡片皮肤应用失败。",
        "One or more cards could not be updated. Check the log and try again.": "一张或多张卡片无法更新。请查看日志后重试。",
        "Complete! All cards updated.": "完成！所有卡片已更新。",
        "Loaded passcode theme '%@' (%d assets)": "已加载密码主题“%@”（%d 个素材）",
        "Failed to inspect .passthm file": "无法解析 .passthm 文件",
        "Please connect and trust your iPhone first.": "请先连接并信任你的 iPhone。",
        "Starting passcode theme flash...": "正在开始刷入密码主题…",
        "Passcode theme applied successfully!": "密码主题应用成功！",
        "Flashing failed (exit code %d)": "刷入失败（退出码 %d）",
        "Poster image loaded · Ready to frame and slice": "海报图片已加载 · 可取景与切片",
        "Updated key %@ · Drag on dialer to reposition or use zoom slider": "已更新按键 %@ · 在键盘上拖动可重新定位，或使用缩放滑块",
        "Cleared key %@": "已清除按键 %@",
        "Cleared all custom keys": "已清除所有自定义按键",
        "Adopted poster slices to individual keys": "已将海报切片应用到单独按键",
        "Loaded '%@' into Theme Creator (%d keys ready to edit)": "已将“%@”载入主题创作器（%d 个按键可编辑）",
        "Theme Creator reset": "主题创作器已重置",
        "Please add at least one key icon or import a poster image first.": "请先添加至少一个按键图标，或导入一张海报图片。",
        "Failed to package theme for flashing.": "主题打包失败，无法刷入。",
        "Please configure at least one key before exporting.": "导出前请至少配置一个按键。",
        "Theme exported successfully to %@": "主题已成功导出到 %@",
        "Failed to export theme: %@": "导出主题失败：%@",
        "Failed to create .passthm zip archive (exit code %d)": "创建 .passthm 压缩包失败（退出码 %d）",

        // MARK: Tab / mode / picker names
        "Apple Wallet": "Apple 钱包",
        "Passcode (.passthm)": "密码主题 (.passthm)",
        "Apply .passthm": "应用 .passthm",
        "Theme Creator": "主题创作器",
        "Poster Slice (Puzzle)": "海报切片（拼图）",
        "All Languages (Universal)": "所有语言（通用）",
        "Ukrainian (uk)": "乌克兰语 (uk)",
        "Russian (ru)": "俄语 (ru)",
        "English (en)": "英语 (en)",
        "Other / Fallback": "其他 / 兜底",
        "Spanish (es)": "西班牙语 (es)",
        "German (de)": "德语 (de)",
        "French (fr)": "法语 (fr)",
        "Polish (pl)": "波兰语 (pl)",
        "Italian (it)": "意大利语 (it)",
        "Portuguese (pt)": "葡萄牙语 (pt)",
        "Turkish (tr)": "土耳其语 (tr)",
        "Japanese (ja)": "日语 (ja)",
        "Korean (ko)": "韩语 (ko)",
        "Chinese (zh)": "中文 (zh)",
        "Arabic (ar)": "阿拉伯语 (ar)",
        "Hebrew (he)": "希伯来语 (he)",
        "Universal (Regular + Bold)": "通用（常规 + 粗体）",
        "Bold Text Only (Fast)": "仅粗体（快速）",
        "Regular Font Only (Fast)": "仅常规字体（快速）",

        // MARK: Messages produced by aircard_backend.py
        "Failed to prepare card artwork": "准备卡片素材失败",
        "Writing %d artwork files (fast batch)...": "正在写入 %d 个素材文件（快速批量）…",
        "Invalidating cache (%@)...": "正在使缓存失效（%@）…",
        "Could not clear Wallet cache (%@); card was not reported as updated.": "无法清除钱包缓存（%@）；卡片未被报告为已更新。",
        "Failed to update %@...": "更新 %@ 失败…",
        "Successfully updated %@...": "已成功更新 %@…",
        "Flashing passcode theme '%@' (%d assets)...": "正在刷入密码主题“%@”（%d 个素材）…",
        "Writing %@ (%d/%d)...": "正在写入 %1$@（%2$d/%3$d）…",
        "Flashing %d asset(s) into %@...": "正在将 %1$d 个素材刷入 %2$@…",
        "Batch write notice for %@, falling back to file-by-file write...": "%@ 批量写入提示，回退为逐文件写入…",
        "[Fallback] Writing %@ (%d/%d)...": "[回退] 正在写入 %1$@（%2$d/%3$d）…",
        "Could not write %d file(s) in %@: %@": "无法在 %2$@ 中写入 %1$d 个文件：%3$@",
        "Passcode theme '%@' successfully applied! Lock your iPhone to check.": "密码主题“%@”应用成功！锁定 iPhone 查看。"
    ]
}
