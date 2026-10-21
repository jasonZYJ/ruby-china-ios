//
//  Log.swift
//  ruby-china-ios
//
//  轻量日志，替代 XCGLogger
//

import Foundation
import os

final class Log {

    enum Level: Int {
        case verbose = 0, debug, info, warning, error, severe, none
    }

    static let shared = Log()

    var outputLevel: Level = {
        #if DEBUG
            return .debug
        #else
            return .none
        #endif
    }()

    private let osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ruby-china-ios", category: "app")

    private func log(_ level: Level, _ items: [Any]) {
        guard level.rawValue >= outputLevel.rawValue, outputLevel != .none else {
            return
        }
        let message = items.map { "\($0)" }.joined(separator: " ")
        switch level {
        case .error, .severe:
            osLogger.error("\(message, privacy: .public)")
        case .warning:
            osLogger.warning("\(message, privacy: .public)")
        default:
            osLogger.info("\(message, privacy: .public)")
        }
    }

    func verbose(_ items: Any...) { log(.verbose, items) }
    func debug(_ items: Any...) { log(.debug, items) }
    func info(_ items: Any...) { log(.info, items) }
    func warning(_ items: Any...) { log(.warning, items) }
    func error(_ items: Any...) { log(.error, items) }
    func severe(_ items: Any...) { log(.severe, items) }
}

/// 全局日志对象（与原 XCGLogger 用法保持一致）
let log = Log.shared
