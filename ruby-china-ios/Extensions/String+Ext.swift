//
//  String+Ext.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/9.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import Foundation

extension String {
    func dateValue(_ format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: self)
    }

    /// ISO8601 日期解析（DateFormatter 创建开销大，必须静态复用，否则列表刷新卡顿）
    private static let iso8601Parser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601ParserNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func dateValueFromISO8601() -> Date? {
        if let date = String.iso8601Parser.date(from: self) {
            return date
        }
        return String.iso8601ParserNoFraction.date(from: self)
    }
}
