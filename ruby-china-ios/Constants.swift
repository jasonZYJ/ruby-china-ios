import UIKit

#if DEBUG1
    let ROOT_URL = "http://localhost:3000"
    let OAUTH_CLIENT_ID = "1c58e228"
    let OAUTH_SECRET = "6d2c9cbef3e4baa56e1cf1d0db41d213105221aeff01281ac7009d21af810c58"
#else
    let ROOT_URL = "https://ruby-china.org"
    let OAUTH_CLIENT_ID = "1c58e228"
    let OAUTH_SECRET = "6d2c9cbef3e4baa56e1cf1d0db41d213105221aeff01281ac7009d21af810c58"
#endif

let COPYRIGHT_URL = "https://github.com/ruby-china/ruby-china-ios/blob/master/LICENSE.md"
let PROJECT_URL = "https://github.com/ruby-china/ruby-china-ios"

let APP_VERSION = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
let USER_AGENT = "turbolinks-app, ruby-china, official, iOS, version:" + APP_VERSION

// MARK: - 颜色（动态色，自动适配深浅色模式）

func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
    return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
}

// Red Theme
let BLACK_COLOR = dynamicColor(light: UIColor(red: 0.04, green: 0.02, blue: 0.02, alpha: 1.0),
                               dark: UIColor(white: 0.95, alpha: 1.0))
let PRIMARY_COLOR = dynamicColor(light: UIColor(red: 0, green: 0, blue: 0, alpha: 1.0),
                                 dark: UIColor(white: 0.92, alpha: 1.0))
/// 主色之上的内容（如登录按钮文字）：浅色模式白、深色模式黑
let ON_PRIMARY_COLOR = dynamicColor(light: UIColor.white, dark: UIColor.black)
let SIDEMENU_NAVBAR_BG_COLOR = dynamicColor(light: UIColor.white, dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0))
let SIDEMENU_BG_COLOR = dynamicColor(light: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
                                     dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0))

let NAVBAR_BG_COLOR = dynamicColor(light: UIColor.white, dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0))
let NAVBAR_BORDER_COLOR = dynamicColor(light: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),
                                       dark: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0))
let NAVBAR_TINT_COLOR = UIColor(red: 1.00, green: 1.00, blue: 0.98, alpha: 1.0)
let TABBAR_BG_COLOR = dynamicColor(light: UIColor.white, dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0))

// MARK: - 深浅色模式偏好

enum AppearanceMode: Int {
    case system = 0
    case light = 1
    case dark = 2

    var userInterfaceStyle: UIUserInterfaceStyle? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var localizedTitle: String {
        switch self {
        case .system: return "appearance system".localized
        case .light: return "appearance light".localized
        case .dark: return "appearance dark".localized
        }
    }

    static var current: AppearanceMode {
        return AppearanceMode(rawValue: UserDefaults.standard.integer(forKey: "appearanceMode")) ?? .system
    }

    static func set(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = mode.userInterfaceStyle ?? .unspecified
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name.appearanceChanged, object: nil)
    }
}
