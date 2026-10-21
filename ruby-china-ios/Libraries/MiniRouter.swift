//
//  MiniRouter.swift
//  ruby-china-ios
//
//  轻量路径路由，替代 Router 库
//  支持字面量段与参数段（可带前缀），如 "/topics/:id"、"/topics/node:id"
//  按绑定顺序优先匹配
//

import Foundation

final class Router {

    struct Route {
        /// 绑定的模式串，如 "/topics/:id"
        let route: String
        /// 匹配到的参数
        let params: [String: String]
        /// 被匹配的 URL
        let url: URL
    }

    final class Request {
        let route: Route

        init(route: Route) {
            self.route = route
        }

        var url: URL {
            return route.url
        }

        func param(_ name: String) -> String? {
            return route.params[name]
        }
    }

    fileprivate typealias Bind = (pattern: String, segments: [String], handler: (Request) -> Void)

    fileprivate var binds: [Bind] = []

    /// 绑定路径模式，先绑定的优先匹配
    func bind(_ pattern: String, handler: @escaping (Request) -> Void) {
        let segments = splitPath(pattern)
        binds.append((pattern, segments, handler))
    }

    /// 匹配 URL；匹配成功时执行对应处理器并返回 Route
    @discardableResult
    func match(_ url: URL) -> Route? {
        let pathSegments = splitPath(url.path)
        for bind in binds {
            if let params = matchSegments(bind.segments, pathSegments) {
                let route = Route(route: bind.pattern, params: params, url: url)
                bind.handler(Request(route: route))
                return route
            }
        }
        return nil
    }

    // MARK: - private

    private func splitPath(_ path: String) -> [String] {
        return path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private func matchSegments(_ pattern: [String], _ path: [String]) -> [String: String]? {
        guard pattern.count == path.count else {
            return nil
        }
        var params = [String: String]()
        for (p, s) in zip(pattern, path) {
            guard let name = paramName(in: p) else {
                if p != s {
                    return nil
                }
                continue
            }
            // 段内模式：前缀字面量 + ":参数名"，如 "node:id"
            if let prefix = paramPrefix(in: p) {
                guard s.hasPrefix(prefix), s.count > prefix.count else {
                    return nil
                }
                params[name] = String(s.dropFirst(prefix.count)).removingPercentEncoding ?? String(s.dropFirst(prefix.count))
            } else {
                params[name] = s.removingPercentEncoding ?? s
            }
        }
        return params
    }

    /// 段内是否包含参数（":" 之后的部分）
    private func paramName(in segment: String) -> String? {
        guard let idx = segment.firstIndex(of: ":") else {
            return nil
        }
        return String(segment[segment.index(after: idx)...])
    }

    /// 参数前的字面量前缀，如 "node:id" 的前缀为 "node"；纯 ":id" 前缀为空
    private func paramPrefix(in segment: String) -> String? {
        guard segment.contains(":") else {
            return nil
        }
        let prefix = segment.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return prefix
    }
}
