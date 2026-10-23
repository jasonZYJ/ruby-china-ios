//
//  RootTopicsViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/15.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import AMScrollingNavbar
import Kingfisher

class RootTopicsViewController: TopicsViewController {

    fileprivate var disappearTime: Date?
    fileprivate var listType = TopicsService.ListType.last_actived
    /// 顶部分段筛选条（参照新版社区客户端布局）：默认 / 最新 / 热门 / 精华
    fileprivate let segmentItems: [(titleKey: String, type: TopicsService.ListType)] = [
        ("seg default", .last_actived),
        ("seg recent", .recent),
        ("seg popular", .popular),
        ("seg excellent", .excellent),
    ]
    fileprivate var segmentButtons: [UIButton] = []

    /// 分段条底色：浅色浅灰 / 深色深灰；选中胶囊：浅色白 / 深色亮灰
    fileprivate static let segmentTrackColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1) : UIColor(white: 0.93, alpha: 1)
    }
    fileprivate static let segmentSelectedColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.30, alpha: 1) : UIColor.white
    }

    fileprivate lazy var avatarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.imageView?.contentMode = .scaleAspectFill
        button.layer.cornerRadius = 15
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(avatarAction), for: .touchUpInside)
        return button
    }()

    /// 头像按钮外层 30x44 容器，与其他导航按钮对齐（按钮用约束垂直居中，
    /// 避免 frame 偏移在系统调整容器高度时导致头像整体偏下）
    fileprivate lazy var avatarItem: UIBarButtonItem = {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 44))
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(avatarButton)
        NSLayoutConstraint.activate([
            avatarButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            avatarButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatarButton.widthAnchor.constraint(equalToConstant: 30),
            avatarButton.heightAnchor.constraint(equalToConstant: 30),
            container.widthAnchor.constraint(equalToConstant: 30),
            container.heightAnchor.constraint(equalToConstant: 44),
        ])
        container.translatesAutoresizingMaskIntoConstraints = false
        return UIBarButtonItem(customView: container)
    }()
    fileprivate lazy var badgeLabel: UILabel = {
        let view = UILabel(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        view.clipsToBounds = true
        view.layer.cornerRadius = 10
        view.backgroundColor = UIColor.red
        view.textColor = UIColor.white
        view.textAlignment = .center
        view.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        view.isHidden = true
        return view
    }()
    /// iOS 26+ 使用系统原生 UIBarButtonItem.badge（customView 上的 UILabel 背景会被
    /// Liquid Glass 合成白化，红底角标显示为白圈）；旧系统走 customView + badgeLabel
    fileprivate var nativeNotificationsItem: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 系统标准纯铃铛（light 细线，与旁边搜索/过滤的细线图标一致）
        let symbolConfig = UIImage.SymbolConfiguration(weight: .light)
        let notificationsIcon = (UIImage(systemName: "bell")?.applyingSymbolConfiguration(symbolConfig)) ?? UIImage(named: "notifications")
        let searchItem = UIBarButtonItem.narrowButtonItem(image: UIImage(named: "search"), target: self, action: #selector(searchAction))

        if #available(iOS 26.0, *) {
            // Liquid Glass 下系统原生 badge 才能正确渲染（红底白字、深浅自适应）
            let item = UIBarButtonItem(image: notificationsIcon, style: .plain, target: self, action: #selector(notificationsAction))
            item.tintColor = PRIMARY_COLOR
            nativeNotificationsItem = item
            navigationItem.rightBarButtonItems = [item, searchItem, avatarItem]
        } else {
            let notificationsButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 44))
            notificationsButton.setImage(notificationsIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
            notificationsButton.tintColor = PRIMARY_COLOR
            notificationsButton.addTarget(self, action: #selector(notificationsAction), for: .touchUpInside)
            let notificationsView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 44))
            notificationsView.addSubview(notificationsButton)
            notificationsView.addSubview(badgeLabel)
            // 固定 customView 尺寸，避免导航栏 autolayout 把按钮收缩到图标宽度（与其他按钮不对齐）
            notificationsView.translatesAutoresizingMaskIntoConstraints = false
            notificationsView.widthAnchor.constraint(equalToConstant: 30).isActive = true
            notificationsView.heightAnchor.constraint(equalToConstant: 44).isActive = true
            notificationsButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                notificationsButton.topAnchor.constraint(equalTo: notificationsView.topAnchor),
                notificationsButton.bottomAnchor.constraint(equalTo: notificationsView.bottomAnchor),
                notificationsButton.leadingAnchor.constraint(equalTo: notificationsView.leadingAnchor),
                notificationsButton.trailingAnchor.constraint(equalTo: notificationsView.trailingAnchor),
            ])
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
            badgeLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
            NSLayoutConstraint.activate([
                badgeLabel.centerXAnchor.constraint(equalTo: notificationsView.trailingAnchor, constant: -4),
                badgeLabel.topAnchor.constraint(equalTo: notificationsView.topAnchor, constant: 2),
            ])
            let notificationsItem = UIBarButtonItem(customView: notificationsView)
            navigationItem.rightBarButtonItems = [notificationsItem, searchItem, avatarItem]
        }
        
        // 旧版依赖"预热 WebView"解决首次 Turbolinks 页面加载慢；现 WKProcessPool 已全局共享，
        // WebContent 进程复用，预热已无必要，且其 view 泄露到屏幕上会造成白色色块
        addObserver()

        setupTableHeader()
        refreshAvatar()
        load(listType: listType, nodeID: 0, offset: 0)
        refreshBadgeLabel()
    }

    /// 列表页右下角毛玻璃浮动快捷组：字体放大/缩小 + 滚动到顶/到底
    /// 挂在列表页所在容器（view.superview）上：固定不随滚动；push 到详情页时随整个容器一起被盖住，天然隐藏
    fileprivate var quickActionsPanel: QuickActionsPanel?

    fileprivate func setupQuickActions() {
        // viewDidLoad 时还没进视图层级，等 viewDidAppear（superview 就绪）后调用
        guard quickActionsPanel == nil, let containerView = view.superview else {
            return
        }
        let panel = QuickActionsPanel(items: [
            QuickActionsPanel.Item(title: "A\u{207A}", action: { [weak self] in self?.fontIncreaseAction() }),
            QuickActionsPanel.Item(title: "A\u{207B}", action: { [weak self] in self?.fontDecreaseAction() }),
            QuickActionsPanel.Item(systemIcon: "chevron.up", action: { [weak self] in self?.scrollToTopAction() }),
        ])
        panel.pinToBottomRight(of: containerView)
        quickActionsPanel = panel
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupQuickActions()
    }

    /// 宽度就绪/旋转后修正表头 frame
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutTableHeader()
    }

    /// 深浅色切换时刷新分段条（选中字重需重设，动态色由 UIKit 自动更新）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateSegmentSelection()
        }
    }

    /// 列表页字号放大/缩小：独立按钮、持久化
    @objc fileprivate func fontIncreaseAction() {
        adjustListFont { FontScale.zoomIn($0) }
    }

    @objc fileprivate func fontDecreaseAction() {
        adjustListFont { FontScale.zoomOut($0) }
    }

    fileprivate func adjustListFont(_ transform: (CGFloat) -> CGFloat) {
        let current = FontScale.current(FontScale.keys.list)
        let next = transform(current)
        guard next != current else {
            return
        }
        FontScale.save(next, key: FontScale.keys.list)
        tableView.reloadData()
        RBHUD.success(FontScale.percentText(next))
    }

    /// 快捷滚动到顶部
    @objc fileprivate func scrollToTopAction() {
        guard let count = topicList?.count, count > 0 else {
            return
        }
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkRefreshContent()
        OAuth2.shared.refreshUnreadNotifications()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        resetDisappearTime()
    }
    
    override func loadTopics(offset: Int, limit: Int, callback: @escaping (APICallbackResponse, [Topic]?) -> ()) {
        TopicsService.list(listType, node_id: nodeID, offset: offset, limit: limit, callback: callback)
    }
}

// MARK: - action methods
@objc 
extension RootTopicsViewController {
    
    func segmentAction(_ sender: UIButton) {
        guard let index = segmentButtons.firstIndex(of: sender) else {
            return
        }
        let type = segmentItems[index].type
        guard type != listType else {
            return
        }
        listType = type
        updateSegmentSelection()
        load(listType: type, nodeID: 0, offset: 0)
    }

    func avatarAction() {
        (tabBarController as? RootViewController)?.displaySideMenu()
    }

    func newTopicAction() {
        guard OAuth2.shared.isLogined else {
            SignInViewController.show()
            return
        }
        TurbolinksSessionLib.shared.action(.Advance, path: "/topics/new")
    }
    
    func searchAction() {
        let vc = SearchViewController()
        vc.onCancel = { sender in
            sender.dismiss(animated: true, completion: nil)
        }
        
        let nc = ScrollingNavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .fullScreen
        // 深色模式下避免转场白闪
        nc.view.backgroundColor = UIColor.systemBackground
        self.present(nc, animated: true, completion: nil)
    }
    
    func notificationsAction() {
        if !OAuth2.shared.isLogined {
            SignInViewController.show()
        } else {
            navigationController?.pushViewController(NotificationsViewController(path: "/notifications"), animated: true)
        }
    }
    
}

// MARK: - private methods

extension RootTopicsViewController {
    fileprivate func addObserver() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self](notification) in
            self?.checkRefreshContent()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self](notification) in
            self?.resetDisappearTime()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.userUnreadNotificationChanged, object: nil, queue: nil) { [weak self](notification) in
            self?.refreshBadgeLabel()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.userChanged, object: nil, queue: nil) { [weak self](notification) in
            self?.refreshAvatar()
        }
    }
    
    fileprivate func refreshBadgeLabel() {
        let count = OAuth2.shared.unreadNotificationCount
        if #available(iOS 26.0, *) {
            nativeNotificationsItem?.badge = count > 0 ? UIBarButtonItem.Badge.count(min(99, count)) : nil
        } else {
            badgeLabel.isHidden = count <= 0
            badgeLabel.text = "\(min(99, count))"
        }
    }
    
    /// 主页顶部大标题 + 新建话题按钮 + 分段筛选条（参照新版社区客户端布局）
    fileprivate func setupTableHeader() {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = "Ruby China"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let newTopicButton = UIButton(type: .system)
        let pencilConfig = UIImage.SymbolConfiguration(weight: .light)
        newTopicButton.setImage(UIImage(systemName: "square.and.pencil", withConfiguration: pencilConfig), for: .normal)
        newTopicButton.tintColor = PRIMARY_COLOR
        newTopicButton.addTarget(self, action: #selector(newTopicAction), for: .touchUpInside)
        newTopicButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(newTopicButton)

        let track = UIView()
        track.backgroundColor = Self.segmentTrackColor
        track.layer.cornerRadius = 12
        track.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(track)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(stack)

        for item in segmentItems {
            let button = UIButton(type: .system)
            button.setTitle(item.titleKey.localized, for: .normal)
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(segmentAction(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            segmentButtons.append(button)
        }
        updateSegmentSelection()

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            newTopicButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            newTopicButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            newTopicButton.widthAnchor.constraint(equalToConstant: 32),
            newTopicButton.heightAnchor.constraint(equalToConstant: 32),
            track.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            track.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            track.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            track.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            track.heightAnchor.constraint(equalToConstant: 36),
            stack.topAnchor.constraint(equalTo: track.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: track.bottomAnchor, constant: -2),
            stack.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: track.trailingAnchor, constant: -2),
        ])

        tableView.tableHeaderView = container
        layoutTableHeader()
    }

    /// tableHeaderView 采用 frame 布局：viewDidLoad 时宽度尚未确定，需在布局后按自适应高度修正
    fileprivate func layoutTableHeader() {
        guard let header = tableView.tableHeaderView else {
            return
        }
        let height = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        let size = CGSize(width: tableView.bounds.width, height: height)
        if header.frame.size != size {
            header.frame = CGRect(origin: .zero, size: size)
            tableView.tableHeaderView = header
        }
    }

    fileprivate func updateSegmentSelection() {
        for (index, button) in segmentButtons.enumerated() {
            let selected = segmentItems[index].type == listType
            button.setTitleColor(selected ? UIColor.label : UIColor.secondaryLabel, for: .normal)
            button.backgroundColor = selected ? Self.segmentSelectedColor : .clear
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
        }
    }

    fileprivate func refreshAvatar() {
        if let user = OAuth2.shared.currentUser {
            avatarButton.kf.setImage(with: user.avatarUrl, for: .normal, placeholder: UIImage(systemName: "person.crop.circle.fill"))
        } else {
            let icon = UIImage(systemName: "person.crop.circle")?.withRenderingMode(.alwaysTemplate)
            avatarButton.setImage(icon, for: .normal)
            avatarButton.tintColor = PRIMARY_COLOR
        }
    }

    fileprivate func load(listType: TopicsService.ListType, nodeID: Int, offset: Int) {
        self.listType = listType
        self.nodeID = nodeID
        self.tableView.mj_header?.beginRefreshing()
    }
    
    fileprivate func resetDisappearTime() {
        disappearTime = Date()
    }
    
    fileprivate func checkRefreshContent() {
        guard let time = disappearTime else {
            return
        }
        disappearTime = nil
        
        if -time.timeIntervalSinceNow > (60 * 60 * 2.0) {
            self.tableView.mj_header?.beginRefreshing()
        }
    }
}
