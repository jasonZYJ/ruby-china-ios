//
//  FontScale.swift
//  ruby-china-ios
//
//  字号缩放：文章列表与文章详情各自独立调节、持久化
//

import UIKit

enum FontScale {
    /// 可用档位（升序）
    static let steps: [CGFloat] = [0.6, 0.8, 1.0, 1.2, 1.4, 1.6]
    /// 列表页 / 详情页各自的 UserDefaults key
    static let keys = (list: "listFontScale", detail: "detailFontScale")

    static func current(_ key: String) -> CGFloat {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? CGFloat(value) : 1.0
    }

    static func save(_ scale: CGFloat, key: String) {
        UserDefaults.standard.set(Double(scale), forKey: key)
    }

    /// 放大：取比当前大一级的档位，已到最大则保持
    static func zoomIn(_ scale: CGFloat) -> CGFloat {
        return steps.first(where: { $0 > scale + 0.01 }) ?? scale
    }

    /// 缩小：取比当前小一级的档位，已到最小则保持
    static func zoomOut(_ scale: CGFloat) -> CGFloat {
        return steps.reversed().first(where: { $0 < scale - 0.01 }) ?? scale
    }

    /// 当前档的百分比文案（如 "120%"），用于调节后的提示
    static func percentText(_ scale: CGFloat) -> String {
        "\(Int((scale * 100).rounded()))%"
    }
}
