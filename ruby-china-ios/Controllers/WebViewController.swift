import UIKit
import WebKit

class WebViewController: VisitableViewController {
    var currentPath = "" {
        didSet {
            visitableURL = urlWithPath(currentPath)
        }
    }
    
    fileprivate lazy var router: Router = {
        let router = Router()
        router.bind("/topics") { [weak self] (req) in
            self?.pageTitle = "title topics".localized
        }
        router.bind("/topics/last") { [weak self] (req) in
            self?.pageTitle = "title last topics".localized
        }
        router.bind("/topics/popular") { [weak self] (req) in
            self?.pageTitle = "title popular topics".localized
        }
        router.bind("/jobs") { [weak self] (req) in
            self?.pageTitle = "title jobs".localized
        }
        router.bind("/account/edit") { [weak self] (req) in
            self?.pageTitle = "title edit account".localized
        }
        router.bind("/notifications") { [weak self] (req) in
            self?.pageTitle = "title notifications".localized
        }
        router.bind("/notes") { [weak self] (req) in
            self?.pageTitle = "title notes".localized
        }
        router.bind("/notes/:id") { [weak self] (req) in
            self?.pageTitle = "title note details".localized
        }
        router.bind("/topics/favorites") { [weak self] (req) in
            self?.pageTitle = "title favorites".localized
        }
        router.bind("/topics/new") { [weak self] (req) in
            self?.pageTitle = "title new topic".localized
        }
        router.bind("/topics/:id/edit") { [weak self] (req) in
            self?.pageTitle = "title edit topic".localized
        }
        router.bind("/topics/:topic_id/replies/:id/edit") { [weak self] (req) in
            self?.pageTitle = "title edit reply".localized
        }
        
        router.bind("/wiki") { [weak self] (req) in
            self?.pageTitle = "title wiki".localized
        }
        router.bind("/wiki/:id") { [weak self] (req) in
            self?.pageTitle = "title wiki details".localized
        }
        
        router.bind("/search") { [weak self] (req) in
            self?.pageTitle = "title search".localized
        }
        return router
    }()
    
    fileprivate var pageTitle = ""
    
    fileprivate lazy var errorView: ErrorView = {
        let view = Bundle.main.loadNibNamed("ErrorView", owner: self, options: nil)!.first as! ErrorView
        view.translatesAutoresizingMaskIntoConstraints = false
        view.retryButton.addTarget(self, action: #selector(retry(_:)), for: .touchUpInside)
        return view
    }()
    
    convenience init(path: String) {
        self.init()
        currentPath = path
        visitableURL = urlWithPath(path)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let webView = WKWebView(frame: view.bounds, configuration: TurbolinksSessionLib.shared.webViewConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.allowsBackForwardNavigationGestures = false
        // 站点没有深色 CSS：引擎保持 light 渲染（避免 WebKit 自动暗化产生白底浅字），
        // 深色模式下再注入覆盖样式，让网页视觉上跟随深色模式
        webView.overrideUserInterfaceStyle = .light
        // 页面背景必须不透明：否则下层视图（如列表页浮动快捷组）会透出来
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(webView)
        self.webView = webView

        TurbolinksSessionLib.shared.visit(self)

        _ = router.match(URL(string: currentPath)!)
        navigationItem.title = pageTitle

        addObserver()
    }
    
    
    
    override func visitableDidRender() {
        // 覆盖 visitableDidRender，避免设置 title
        navigationItem.title = pageTitle
        // 页面渲染完成后按当前模式套用网页主题（每次 turbolinks 换页都需重新注入）
        applyWebPageTheme()
    }

    // 深浅色切换时网页跟随
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyWebPageTheme()
        }
    }

    /// 站点没有深色 CSS：深色模式注入覆盖样式；字号缩放注入正文规则（浅色/默认字号时仅移除）
    func applyWebPageTheme() {
        guard let webView = webView else {
            return
        }
        let dark = traitCollection.userInterfaceStyle == .dark
        let js = WebViewController.themeJS(dark: dark, fontScale: FontScale.current(FontScale.keys.detail))
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func themeJS(dark: Bool, fontScale: CGFloat) -> String {
        var css = ""
        if dark {
            css += """
            html,body{background:#161618!important;color:#E6E6E9!important}
            div,section,article,aside,header,footer,nav,ul,ol,li,dl,dd,dt,form,fieldset,blockquote,figure,table,tr,td,th,span,p{background-color:transparent!important}
            .panel,.panel-default,.panel-body,.panel-heading,.panel-footer,.list-group-item,
            .card,.topic-detail,.markdown-body,.reply,.media,.navbar,.dropdown-menu,
            .form-control,.btn-default,.breadcrumb,.pagination>li>a,.table{background-color:#1E1E21!important;border-color:#2E2E33!important}
            .markdown-body,.markdown-body p,.markdown-body li,.markdown-body span,.markdown-body div,
            .markdown-body td,.markdown-body blockquote,.reply,.reply p,.reply span,.reply div,.media-body{color:#DEDEE2!important}
            .markdown-body a,.reply a{color:#6EA8FE!important}
            .markdown-body strong,.markdown-body h1,.markdown-body h2,.markdown-body h3,
            .markdown-body h4,.markdown-body h5,.markdown-body h6,.media-heading{color:#F0F0F2!important}
            pre,code{background:#26262A!important;color:#DCDCE0!important}
            img{opacity:.92}
            """
        }
        if abs(fontScale - 1.0) > 0.01 {
            // 站点 CSS 对正文字号有高优先级定义，font-size 覆盖不可靠；
            // 改用 body zoom（等价浏览器缩放，文字/图片整体缩放且必然生效）
            css += "body{zoom:\(String(format: "%.2f", fontScale))!important}"
        }
        guard !css.isEmpty else {
            return "(function(){ document.getElementById('rc-native-theme')?.remove(); })();"
        }
        return """
        (function(){
          document.getElementById('rc-native-theme')?.remove();
          var s = document.createElement('style');
          s.id = 'rc-native-theme';
          s.textContent = `\(css)`;
          document.head.appendChild(s);
        })();
        """
    }
    
}

// MARK: - public

extension WebViewController {
    
    func presentError(_ error: RCError) {
        errorView.error = error
        view.addSubview(errorView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: [], metrics: nil, views: ["view": errorView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: ["view": errorView]))
    }
    
    func clearSession() {
        let js = "document.cookie = '_homeland_session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';";
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
}

// MARK: - action
@objc
extension WebViewController {
    
    func reloadByLoginStatusChanged() {
        visitableURL = urlWithPath(currentPath)
        if isViewLoaded {
            reloadVisitable()
        }
    }
    
    func retry(_ sender: AnyObject) {
        errorView.removeFromSuperview()
        reloadVisitable()
    }
    
    func shareAction() {
        guard let webView = self.webView,
            let title = webView.title,
            let url = webView.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        components.query = nil
        components.fragment = nil
        if let url = components.url {
            share(title, url: url)
        }
    }
    
    func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    func moreAction() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let shareAction = UIAlertAction(title: "share".localized, style: .default, handler: { [weak self] action in
            self?.shareAction()
        })
        sheet.addAction(shareAction)
        
        let cancelAction = UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil)
        sheet.addAction(cancelAction)
        self.present(sheet, animated: true, completion: nil)
    }
    
}

// MARK: - private

extension WebViewController {
    
    fileprivate func urlWithPath(_ path: String) -> URL {
        let newPath = path.replacingOccurrences(of: "%23", with: "#")
        var urlComponents = URLComponents(string: newPath)!
        
        let rootURLComponents = URLComponents(string: ROOT_URL)!
        urlComponents.scheme = rootURLComponents.scheme
        urlComponents.host = rootURLComponents.host
        urlComponents.port = rootURLComponents.port
        
        return urlComponents.url!
    }
    
    fileprivate func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadByLoginStatusChanged), name: NSNotification.Name.userSignin, object: nil)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.userSignout, object: nil, queue: nil) { [weak self] (notification) in
            guard let `self` = self else {
                return
            }
            self.clearSession()
            self.reloadByLoginStatusChanged()
        }
    }
    
    fileprivate func share(_ textToShare: String, url: URL) {
        let objectsToShare = [textToShare, url] as [Any]
        let activityViewController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }
}
