//
//  TopicExcerptService.swift
//  ruby-china-ios
//
//  Created by Assistant on 26/10/23.
//  Copyright © 2026年 ruby-china. All rights reserved.
//

import Foundation
import SwiftyJSON

/// 话题摘要服务：列表接口不含正文，按需请求详情接口提取正文开头两行摘要
/// - 内存缓存（NSCache）：同一话题整个 App 生命周期只请求一次
/// - 回调按 topicID 存储（排队出队后仍能正确回调各自的行）
/// - inFlight 去重 + 并发限流（最多 3 个同时请求），快速滚动经过的行排队依次补齐
/// - 超时兜底：APIRequest 在 401 时不会回调，15s 强制放行避免卡死整个队列
final class TopicExcerptService {

    static let shared = TopicExcerptService()

    private let cache = NSCache<NSNumber, NSString>()
    private var inFlight = Set<Int>()
    private var completions: [Int: [() -> Void]] = [:]
    private var pendingQueue: [Int] = []
    private var activeCount = 0
    private let mutex = NSLock()

    private let maxConcurrent = 3
    private let requestTimeout: TimeInterval = 15
    /// 摘要最大长度（字符）
    private let maxExcerptLength = 120

    func cachedExcerpt(topicID: Int) -> String? {
        mutex.lock()
        defer { mutex.unlock() }
        return cache.object(forKey: NSNumber(value: topicID)) as String?
    }

    /// 确保摘要可用：无缓存则排队请求详情，完成后回调（回调在主线程）
    func ensureExcerpt(topicID: Int, completion: @escaping () -> Void) {
        mutex.lock()
        if cache.object(forKey: NSNumber(value: topicID)) != nil {
            mutex.unlock()
            return
        }
        if inFlight.contains(topicID) {
            // 请求已在途/在队列：只追加回调
            completions[topicID, default: []].append(completion)
            mutex.unlock()
            return
        }
        inFlight.insert(topicID)
        completions[topicID] = [completion]
        if activeCount >= maxConcurrent {
            pendingQueue.append(topicID)
            mutex.unlock()
            return
        }
        activeCount += 1
        mutex.unlock()

        fire(topicID)
    }

    private func fire(_ topicID: Int) {
        // 超时兜底：401/网络黑洞时 APIRequest 不回调，强制放行防止队列饿死
        DispatchQueue.main.asyncAfter(deadline: .now() + requestTimeout) { [weak self] in
            self?.finishOne(topicID: topicID)
        }
        TopicsService.detail(topicID) { [weak self] (_, topic: Topic?, _) in
            guard let self = self else {
                return
            }
            if let body = topic?.body {
                let excerpt = self.cleanMarkdown(body)
                self.mutex.lock()
                // 空摘要也缓存（如纯图片帖），避免重复请求
                self.cache.setObject(excerpt as NSString, forKey: NSNumber(value: topicID))
                self.mutex.unlock()
            }
            self.finishOne(topicID: topicID)
        }
    }

    /// 完成一单：释放槽位、唤醒队列、执行该 topic 的所有回调（幂等，超时兜底与正常完成只会生效一次）
    private func finishOne(topicID: Int) {
        var callbacks: [() -> Void] = []
        mutex.lock()
        guard inFlight.contains(topicID) else {
            mutex.unlock()
            return
        }
        inFlight.remove(topicID)
        callbacks = completions[topicID] ?? []
        completions[topicID] = nil
        if pendingQueue.isEmpty {
            activeCount = max(activeCount - 1, 0)
        } else {
            // 槽位直接转移给下一个排队请求，activeCount 不变
            let next = pendingQueue.removeFirst()
            mutex.unlock()
            fire(next)
            callbacks.forEach { $0() }
            return
        }
        mutex.unlock()
        callbacks.forEach { $0() }
    }

    /// Markdown → 纯文本摘要：去图片/链接/行首标记/强调符号，压缩空白
    private func cleanMarkdown(_ body: String) -> String {
        var text = body

        // 去图片 ![alt](url)
        if let regex = try? NSRegularExpression(pattern: "!\\[[^\\]]*\\]\\([^)]*\\)") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        // 链接 [text](url) → text
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]*)\\]\\([^)]*\\)") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1")
        }
        // 行首引用/列表/标题符号
        if let regex = try? NSRegularExpression(pattern: "^[ \t]*(#{1,6}|>|[-*+]|\\d+\\.)[ \t]+", options: [.anchorsMatchLines]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        // 强调符号 * _ ~ `
        if let regex = try? NSRegularExpression(pattern: "[*_~`]+") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        // 空白压缩：换行合并为空格
        if let regex = try? NSRegularExpression(pattern: "\\s+") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > maxExcerptLength {
            let index = text.index(text.startIndex, offsetBy: maxExcerptLength)
            text = String(text[..<index]) + "…"
        }
        return text
    }
}
