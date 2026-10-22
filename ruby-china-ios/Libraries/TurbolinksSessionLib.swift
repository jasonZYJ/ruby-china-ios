//
//  TurbolinksSessionLib.swift
//  ruby-china-ios
//
//  Created by kelei on 16/7/27.
//  Copyright © 2016年 ruby-china. All rights reserved.
//
//  轻量 WebView 会话与路由，替代 Turbolinks + Router
//

import UIKit
import WebKit
import SafariServices
import SKPhotoBrowser

/// 访问动作（保留原 Turbolinks 命名，减少调用方改动）
enum Action {
    case Advance
    case Replace
    case Restore
}

/// 可被会话访问的页面基类（替代 Turbolinks 的 VisitableViewController）
class VisitableViewController: UIViewController {

    var visitableURL: URL = URL(string: ROOT_URL)!

    /// 由会话挂载的 WebView
    var webView: WKWebView?

    /// 重新加载当前可访问 URL
    func reloadVisitable() {
        guard let webView = webView else {
            return
        }
        webView.load(URLRequest(url: visitableURL))
    }

    /// 页面渲染完成回调
    func visitableDidRender() {}
}

class TurbolinksSessionLib: NSObject {
    static let shared: TurbolinksSessionLib = {
        return TurbolinksSessionLib()
    }()

    /// 当前会话正在访问的页面
    fileprivate weak var currentVisitable: WebViewController?

    func visit(_ visitable: WebViewController) {
        guard let webView = visitable.webView else {
            return
        }
        currentVisitable = visitable
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: visitable.visitableURL))
    }

    /// 重新载入主导航栈顶部的 Web 页面
    func reload() {
        guard let webViewController = topmostMainWebViewController() else {
            return
        }
        currentVisitable = webViewController
        webViewController.reloadVisitable()
    }

    fileprivate lazy var router: Router = {
        let router = Router()
        router.bind("/account/edit") { req in
            self.presentEditAccountController(req.route.route)
        }
        router.bind("/topics/new") { req in
            self.presentEditTopicController(req.route.route)
        }
        router.bind("/topics/favorites") { req in
            self.pushFavoritesController()
        }
        router.bind("/topics/node:id") { req in
            if let idString = req.param("id"), let nodeID = Int(idString) {
                self.pushNodeTopicsController(nodeID)
            }
        }
        router.bind("/topics/:id/edit") { req in
            self.presentEditTopicController("/topics/\(req.param("id")!)/edit")
        }
        router.bind("/account/sign_in") { _ in
            self.presentLoginController()
        }
        router.bind("/account/sign_up") { _ in
            SignUpViewController.show()
        }
        router.bind("/topics/:topic_id/replies/:id/edit") { req in
            let path = "/topics/\(req.param("topic_id")!)/replies/\(req.param("id")!)/edit"
            self.presentEditReplyController(path)
        }

        router.bind("/topics/:id") { req in
            guard var idString = req.param("id") else {
                return
            }
            if req.url.fragment != nil {
                idString = idString.replacingOccurrences(of: "%23", with: "#")
            }
            let idStringList = idString.split { $0 == "#" }.map(String.init)
            if
                idStringList.count > 0,
                let id = Int(idStringList[0]),
                let currentViewController = UIApplication.currentViewController(),
                let navigationController = currentViewController.navigationController {

                let vc = TopicDetailsViewController(topicID: id, topicPath: req.url.absoluteString)
                if let oldVC = currentViewController as? TopicDetailsViewController, oldVC.topicID == id {
                    navigationController.popViewController(animated: false)
                    navigationController.pushViewController(vc, animated: false)
                } else {
                    navigationController.pushViewController(vc, animated: true)
                }
            }
        }
        return router
    }()

    let kMessageHandlerName = "NativeApp"

    /// turbolinks JS 适配器消息通道名
    fileprivate let kTurbolinksMessageHandlerName = "turbolinks"

    /// turbolinks JS 适配器（源自 turbolinks-ios，MIT 协议，稍作精简）：
    /// 监听页面 turbolinks 事件并转发到原生，用于拦截 JS 发起的页面跳转
    fileprivate let turbolinksAdapterScriptSource = """
    (function() {
        if (!(window.Turbolinks && Turbolinks.controller && window.webkit && webkit.messageHandlers && webkit.messageHandlers.turbolinks)) {
            return
        }
        function WebView(controller, messageHandler) {
            this.controller = controller
            this.messageHandler = messageHandler
            controller.adapter = this
        }
        WebView.prototype = {
            pageLoaded: function() {
                this.postMessageAfterNextRepaint("pageLoaded", {})
            },
            visitProposedToLocationWithAction: function(location, action) {
                this.postMessage("visitProposed", { location: location.absoluteURL, action: action })
            },
            visitRequestFailedWithStatusCode: function(visit, statusCode) {
                this.postMessage("visitRequestFailed", { statusCode: statusCode })
            },
            visitRendered: function(visit) {
                this.postMessageAfterNextRepaint("visitRendered", {})
            },
            visitCompleted: function(visit) {
                this.postMessageAfterNextRepaint("visitCompleted", {})
            },
            pageInvalidated: function() {
                this.postMessage("pageInvalidated")
            },
            postMessage: function(name, data) {
                this.messageHandler.postMessage({ name: name, data: data || {} })
            },
            postMessageAfterNextRepaint: function(name, data) {
                if (document.hidden) {
                    this.postMessage(name, data)
                } else {
                    var postMessage = this.postMessage.bind(this, name, data)
                    requestAnimationFrame(function() {
                        requestAnimationFrame(postMessage)
                    })
                }
            }
        }
        this.webView = new WebView(Turbolinks.controller, webkit.messageHandlers.turbolinks)
        webView.pageLoaded()
    })()
    """

    lazy var webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: self.kMessageHandlerName)
        configuration.userContentController.add(self, name: self.kTurbolinksMessageHandlerName)
        let adapterScript = WKUserScript(source: self.turbolinksAdapterScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(adapterScript)
        configuration.applicationNameForUserAgent = USER_AGENT
        configuration.processPool = WKProcessPool()
        return configuration
    }()

    func action(_ action: Action, path: String) {
        guard
            let newPath = path.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed),
            let url = URL(string: newPath) else {
            return
        }
        if let _ = router.match(url) {
            return
        }

        var realAction = action
        // 如果要访问的地址与栈顶页面相同，直接重新载入，而不是创建新的页面
        if let topWebViewController = topmostMainWebViewController(), topWebViewController.currentPath == path {
            realAction = .Restore
        }

        if (realAction == .Restore) {
            guard let topWebViewController = topmostMainWebViewController() else {
                return
            }
            topWebViewController.visitableURL = URL(string: (ROOT_URL as NSString).appendingPathComponent(newPath))!
            topWebViewController.reloadVisitable()
        } else {
            guard let navigationController = UIApplication.currentViewController()?.navigationController else {
                return
            }

            let visitable = WebViewController(path: newPath)
            if realAction == .Advance {
                navigationController.pushViewController(visitable, animated: true)
            } else if realAction == .Replace {
                navigationController.popViewController(animated: false)
                navigationController.pushViewController(visitable, animated: false)
            } else {
                navigationController.pushViewController(visitable, animated: false)
            }
        }
    }

    func safariOpen(_ url: URL) {
        let safariViewController = SFSafariViewController(url: url)
        UIApplication.currentViewController()?.present(safariViewController, animated: true, completion: nil)
    }

    fileprivate func presentLoginController() {
        SignInViewController.show().delegate = self
    }

    fileprivate func presentEditTopicController(_ path: String) {
        if (!OAuth2.shared.isLogined) {
            presentLoginController()
            return
        }

        let controller = NewTopicViewController(path: path)
        controller.delegate = self

        let navController = ThemeNavigationController(rootViewController: controller)
        UIApplication.currentViewController()?.present(navController, animated: true, completion: nil)
    }

    fileprivate func presentEditReplyController(_ path: String) {
        if (!OAuth2.shared.isLogined) {
            presentLoginController()
            return
        }

        let controller = EditReplyViewController(path: path)
        controller.delegate = self
        let navController = ThemeNavigationController(rootViewController: controller)
        UIApplication.currentViewController()?.present(navController, animated: true, completion: nil)
    }

    fileprivate func presentEditAccountController(_ path: String) {
        let controller = EditAccountViewController(path: path)
        controller.delegate = self
        let navController = ThemeNavigationController(rootViewController: controller)
        UIApplication.currentViewController()?.present(navController, animated: true, completion: nil)
    }

    fileprivate func presentImageBrowserController(_ url: URL) {
        if (SKCache.sharedCache.imageCache as? CustomImageCache) == nil {
            SKCache.sharedCache.imageCache = CustomImageCache()
        }

        let photo = SKPhoto.photoWithImageURL(url.absoluteString)
        photo.shouldCachePhotoURLImage = true

        let browser = SKPhotoBrowser(photos: [photo])
        UIApplication.currentViewController()?.present(browser, animated: true, completion: nil)
    }

    fileprivate func pushNodeTopicsController(_ nodeID: Int) {
        let controller = NodeTopicsViewController(nodeID: nodeID)
        UIApplication.currentViewController()?.navigationController?.pushViewController(controller, animated: true)
    }

    fileprivate func pushFavoritesController() {
        if (!OAuth2.shared.isLogined) {
            presentLoginController()
            return
        }
        let controller = FavoriteTopicsViewController()
        UIApplication.currentViewController()?.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - helpers

    /// path + query + fragment（等价原 Router 库的 requestURI），保留编码形态，
    /// 确保路由与页面 URL 不丢 query / 锚点
    fileprivate func requestURI(of url: URL) -> String {
        var result = url.path
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let query = components.percentEncodedQuery {
                result += "?" + query
            }
            if let fragment = components.percentEncodedFragment {
                result += "#" + fragment
            }
        }
        return result
    }

    /// 主导航栈（App 根部 ThemeNavigationController）
    fileprivate var rootNavigationController: UINavigationController? {
        guard let rootViewController = UIApplication.keyWindow?.rootViewController else {
            return nil
        }
        return rootViewController as? UINavigationController
    }

    /// 主导航栈顶部的 Web 页面
    fileprivate func topmostMainWebViewController() -> WebViewController? {
        guard let viewControllers = rootNavigationController?.viewControllers else {
            return nil
        }
        for viewController in viewControllers.reversed() {
            if let webViewController = viewController as? WebViewController {
                return webViewController
            }
        }
        return nil
    }
}

// MARK: - SignInViewControllerDelegate

extension TurbolinksSessionLib: SignInViewControllerDelegate {
    func signInViewControllerDidAuthenticate(_ sender: SignInViewController) {
        // 重新载入之前的页面
        reload()
    }
}

// MARK: - PopupWebViewControllerDelegate

extension TurbolinksSessionLib: PopupWebViewControllerDelegate {
    func popupWebViewControllerDidFinished(_ controller: PopupWebViewController, toURL url: URL?) {
        if (url == nil) {
            reload()
            return
        }

        if (controller.currentPath == "topics/new") {
            action(.Advance, path: url!.path)
        } else {
            reload()
        }
    }
}

// MARK: - WKNavigationDelegate

extension TurbolinksSessionLib: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> ()) {

        // PopupViewController
        if let popupWebViewController = currentVisitable as? PopupWebViewController {
            popupWebViewController.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // 程序发起的加载（初始 visit、reload、JS location 跳转、iframe 内嵌等非用户点击）直接放行。
        // turbolinks 接管的页面由 JS 适配器通过 visitProposed 消息驱动原生路由；
        // 未接管页面的用户点击（linkActivated）走下方路由拦截。
        // 注意：若不在此放行，初始 load 会被下方路由逻辑 cancel 并触发 reload，造成死循环白屏。
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }

        switch url.scheme {
        case "about":
            decisionHandler(.allow)
            return
        case "mailto":
            decisionHandler(.cancel)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        default:
            break
        }

        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif"].first(where: { $0 == ext }) != nil {
            // 查看图片
            presentImageBrowserController(url)
        } else if let host = url.host, host != URL(string: ROOT_URL)!.host! {
            // 外部网站, open in SafariView
            safariOpen(url)
        } else {
            // 内部链接 → 原生路由
            action(.Advance, path: requestURI(of: url))
        }

        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> ()) {
        guard let httpResponse = navigationResponse.response as? HTTPURLResponse else {
            decisionHandler(.allow)
            return
        }

        switch httpResponse.statusCode {
        case 401:
            if !OAuth2.shared.isLogined {
                presentLoginController()
            }
        case 404:
            if let webViewController = currentVisitable {
                webViewController.presentError(.HTTPNotFoundError)
            }
        case 400..<600:
            if let webViewController = currentVisitable {
                webViewController.presentError(RCError(HTTPStatusCode: httpResponse.statusCode))
            }
        default:
            break
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.error(["webView didFail", error])
        if let webViewController = currentVisitable {
            webViewController.presentError(.NetworkError)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log.error(["webView didFailProvisionalNavigation", error])
        if let webViewController = currentVisitable {
            webViewController.presentError(.NetworkError)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentVisitable?.visitableDidRender()
    }
}

// MARK: - WKScriptMessageHandler

extension TurbolinksSessionLib: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case kMessageHandlerName:
            handleNativeAppMessage(message)
        case kTurbolinksMessageHandlerName:
            handleTurbolinksMessage(message)
        default:
            break
        }
    }

    /// window.webkit.messageHandlers.NativeApp.postMessage({func: "alert_success", message: "成功"})
    fileprivate func handleNativeAppMessage(_ message: WKScriptMessage) {
        guard let dic = message.body as? [String: AnyObject] else {
            return
        }
        if let funcName = dic["func"] as? String, let message = dic["message"] as? String {
            if funcName == "alert_success" {
                RBHUD.success(message)
            } else {
                RBHUD.error(message)
            }
        }
    }

    /// turbolinks JS 适配器消息
    fileprivate func handleTurbolinksMessage(_ message: WKScriptMessage) {
        guard let dic = message.body as? [String: AnyObject],
            let name = dic["name"] as? String else {
            return
        }
        let data = dic["data"] as? [String: AnyObject] ?? [:]

        switch name {
        case "visitProposed":
            guard let locationString = data["location"] as? String, let url = URL(string: locationString) else {
                return
            }
            handleProposedVisit(to: url, actionString: data["action"] as? String)
        case "pageLoaded", "visitRendered", "visitCompleted":
            currentVisitable?.visitableDidRender()
        case "visitRequestFailed":
            let statusCode = data["statusCode"] as? Int ?? 0
            handleVisitFailure(statusCode: statusCode)
        case "pageInvalidated":
            reload()
        default:
            break
        }
    }

    /// 处理 turbolinks JS 提议的页面访问（等价于原 SessionDelegate didProposeVisitToURL）
    fileprivate func handleProposedVisit(to url: URL, actionString: String?) {
        let visitAction: Action
        switch actionString {
        case "replace": visitAction = .Replace
        case "restore": visitAction = .Restore
        default: visitAction = .Advance
        }

        if let popupWebViewController = currentVisitable as? PopupWebViewController {
            if url.path != popupWebViewController.currentPath {
                popupWebViewController.doDidFinished(toURL: url)
            }
            return
        }

        action(visitAction, path: requestURI(of: url))
    }

    /// 处理 turbolinks JS 报告的访问失败（等价于原 SessionDelegate didFailRequestForVisitable）
    fileprivate func handleVisitFailure(statusCode: Int) {
        guard let webViewController = currentVisitable else {
            return
        }
        switch statusCode {
        case 401:
            if !OAuth2.shared.isLogined {
                presentLoginController()
            }
        case 404:
            webViewController.presentError(.HTTPNotFoundError)
        default:
            webViewController.presentError(RCError(HTTPStatusCode: statusCode))
        }
    }
}

// MARK: - WKUIDelegate

extension TurbolinksSessionLib: WKUIDelegate {
    // 这个方法是在HTML中调用了JS的alert()方法时，就会回调此API。
    // 注意，使用了`WKWebView`后，在JS端调用alert()就不会在HTML
    // 中显示弹出窗口。因此，我们需要在此处手动弹出ios系统的alert。
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler()
        }))
        UIApplication.currentViewController()?.present(alert, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Ruby China", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(true)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        UIApplication.currentViewController()?.present(alert, animated: true, completion: nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: prompt, message: defaultText, preferredStyle: .alert)
        alert.addTextField { (textField: UITextField) -> Void in
            textField.textColor = UIColor.red
        }
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(alert.textFields![0].text!)
        }))
        UIApplication.currentViewController()?.present(alert, animated: true, completion: nil)
    }
}
