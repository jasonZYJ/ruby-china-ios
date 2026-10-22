//
//  TopicsTableViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/13.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import AMScrollingNavbar

class TopicsViewController: UITableViewController {

    fileprivate let kCellReuseIdentifier = "TOPIC_CELL"
    fileprivate var isLoading = false
    fileprivate var errorView: ErrorView?
    
    let defaultLimit = 40
    var topicList: [Topic]?
    var nodeID = 0
    func loadTopics(offset: Int, limit: Int, callback: @escaping (APICallbackResponse, [Topic]?) -> ()) {
        fatalError("loadTopics(offset:callback:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 不再启用导航栏跟随滚动收缩：收缩/展开与 self-sizing 行高修正叠加，
        // 滚回顶部时 contentOffset 漂移会让导航栏盖住第一行（保留导航栏常驻更稳）
    }

    // 深浅色切换后重新渲染 cell（标题 SF 图标按 trait 缓存，需重建）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            tableView.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        
        tableView.register(TopicCell.self, forCellReuseIdentifier: kCellReuseIdentifier)
        tableView.separatorColor = UIColor.separator
        tableView.tableFooterView = UIView()
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        tableView.rowHeight = UITableView.automaticDimension
        // 预估高度需接近真实值（88~110）：原 56 偏小太多，快速滑动时 contentOffset 跳变导致 cell 重叠；
        // 注意不能设 0，否则 self-sizing 被关闭、行高回落 44pt 默认值，标题会被裁掉
        tableView.estimatedRowHeight = 96
        tableView.headerWithRefreshingBlock { [weak self] in
            guard let `self` = self else {
                return
            }
            self.errorView?.removeFromSuperview()
            self.load(offset: 0, limit: self.defaultLimit)
        }
        tableView.footerWithRefreshingBlock { [weak self] in
            guard let `self` = self else {
                return
            }
            self.load(offset: self.topicList?.count ?? 0, limit: self.defaultLimit)
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return topicList == nil ? 0 : topicList!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kCellReuseIdentifier, for: indexPath) as! TopicCell
        cell.fontScale = FontScale.current(FontScale.keys.list)
        cell.data = topicList?[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let data = topicList?[indexPath.row] else {
            return
        }
        let vc = TopicDetailsViewController(topicID: data.id)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension TopicsViewController: ScrollingNavigationControllerDelegate {
    
    func scrollingNavigationController(_ controller: ScrollingNavigationController, didChangeState state: NavigationBarState) {
        switch state {
        case .collapsed:
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navigationController?.navigationBar.shadowImage = UIImage()
        case .expanded:
            navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
            navigationController?.navigationBar.shadowImage = nil
        case .scrolling: break
        }
    }
    
}

// MARK: - public

extension TopicsViewController {
    
    func load(offset: Int, limit: Int) {
        if isLoading { return }
        isLoading = true
        // 首次进入（无数据）时用居中的 HUD 转圈，替代 mj_header 顶部的加载圈
        let initialLoading = offset == 0 && (topicList == nil || topicList!.isEmpty)
        if initialLoading {
            RBHUD.progress(nil)
        }

        loadTopics(offset: offset, limit: limit) { [weak self] (response, result) in
            guard let `self` = self else {
                return
            }
            self.isLoading = false
            if initialLoading {
                RBHUD.progressHidden()
            }
            
            if let header = self.tableView.mj_header, header.isRefreshing {
                header.endRefreshing()
            }
            if let footer = self.tableView.mj_footer, footer.isRefreshing {
                footer.endRefreshing()
            }
            self.tableView.mj_footer?.isHidden = result == nil ? true : (result!.count < limit)
            
            if let topics = result {
                if self.topicList == nil || offset == 0 {
                    self.topicList = topics
                } else {
                    self.topicList = (self.topicList ?? []) + topics
                }
                self.tableView.reloadData()
            } else {
                var error: RCError!
                switch response.result {
                case .success:
                    guard let statusCode = response.response?.statusCode else {
                        return
                    }
                    switch statusCode {
                    case 200..<300:
                        return
                    case 404:
                        error = RCError.HTTPNotFoundError
                    default:
                        error = RCError(HTTPStatusCode: statusCode)
                    }
                case .failure(let err):
                    error = RCError(title: "网络连接错误", message: err.localizedDescription)
                }
                
                if let list = self.topicList , list.count > 0 {
                    RBHUD.error(error.message)
                } else {
                    self.presentError(error)
                }
            }
        }
    }
    
}

// MARK: - action
@objc
extension TopicsViewController {
    
    func errorViewRetryAction() {
        tableView.mj_header?.beginRefreshing()
    }
    
}

// MARK: - private

extension TopicsViewController {
    
    fileprivate func presentError(_ error: RCError) {
        errorView?.removeFromSuperview()
        
        errorView = Bundle.main.loadNibNamed("ErrorView", owner: self, options: nil)!.first as? ErrorView
        if errorView == nil {
            return
        }
        
        errorView!.retryButton.addTarget(self, action: #selector(errorViewRetryAction), for: .touchUpInside)
        errorView!.error = error
        view.addSubview(errorView!)
        errorView!.snp.remakeConstraints { (make) in
            make.edges.equalToSuperview()
            var screenSize = UIScreen.main.bounds.size
            screenSize.height -= 64 + 49
            make.size.equalTo(screenSize)
        }
    }
    
}
