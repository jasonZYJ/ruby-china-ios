//
//  RootTopicsViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/15.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit

class RootTopicsViewController: TopicsViewController {
    
    private var disappearTime: NSDate?
    private var filterViewController: TopicsFilterViewController?
    private var filterWindow: UIWindow?
    private var filterData = TopicsFilterViewController.NodeData.listType(.last_actived)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(named: "new"), style: .Plain, target: self, action: #selector(newTopicAction)),
            UIBarButtonItem(image: UIImage(named: "search"), style: .Plain, target: self, action: #selector(searchAction)),
            UIBarButtonItem(image: UIImage(named: "filter"), style: .Plain, target: self, action: #selector(filterAction)),
        ]
        
        addObserver()
        
        resetTitle(filterData)
        reloadTopics(filterData)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        checkRefreshContent()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        resetDisappearTime()
    }
    
}

// MARK: - action methods

extension RootTopicsViewController {
    
    func closefilterAction() {
        closeFilterViewController()
    }
    
    func filterAction() {
        showFilterViewController()
    }
    
    func searchAction() {
        let vc = SearchViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func newTopicAction() {
        TurbolinksSessionLib.sharedInstance.actionToPath("/topics/new", withAction: .Replace)
    }
    
}

// MARK: - private methods

extension RootTopicsViewController {
    private func addObserver() {
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { [weak self](notification) in
            self?.checkRefreshContent()
        }
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { [weak self](notification) in
            self?.resetDisappearTime()
        }
    }
    
    private func showFilterViewController() {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window.windowLevel = UIWindowLevelAlert
        
        let closeButton = UIButton()
        closeButton.addTarget(self, action: #selector(closefilterAction), forControlEvents: .TouchUpInside)
        var frame = window.bounds
        frame.size.height = 64
        closeButton.frame = frame
        window.addSubview(closeButton)
        
        let vc = TopicsFilterViewController()
        vc.selectedData = filterData
        vc.onChangeSelect = { [weak self] (sender) in
            guard let `self` = self, data = sender.selectedData else {
                return
            }
            self.filterData = data
            self.resetTitle(data)
            self.reloadTopics(data)
            self.closefilterAction()
        }
        frame = window.bounds
        frame.origin.y = closeButton.frame.size.height
        frame.size.height -= frame.origin.y
        vc.view.frame = frame
        window.addSubview(vc.view)
        
        window.makeKeyAndVisible()
        vc.view.alpha = 0
        UIView.animateWithDuration(0.3, animations: {
            vc.view.alpha = 1
        })
        
        filterWindow = window
        filterViewController = vc
    }
    
    private func closeFilterViewController() {
        guard let vc = filterViewController, window = filterWindow else {
            return
        }
        UIView.animateWithDuration(0.3, animations: {
            vc.view.alpha = 0
        }, completion: { _ in
            vc.removeFromParentViewController()
            vc.view.removeFromSuperview()
            window.resignKeyWindow()
            self.filterViewController = nil
            self.filterWindow = nil
        })
    }
    
    private func resetTitle(filterData: TopicsFilterViewController.NodeData) {
        switch filterData {
        case let .listType(type):
            navigationItem.title = type == .last_actived ? "title topics".localized : filterData.getName()
        case let .node(_, name):
            navigationItem.title = name
        }
        
        tabBarController?.title = navigationItem.title
    }
    
    private func reloadTopics(filterData: TopicsFilterViewController.NodeData) {
        switch filterData {
        case let .listType(type):
            load(listType: type, nodeID: 0, offset: 0)
        case let .node(id, _):
            load(listType: .last_actived, nodeID: id, offset: 0)
        }
    }
    
    private func resetDisappearTime() {
        disappearTime = NSDate()
    }
    
    private func checkRefreshContent() {
        guard let time = disappearTime else {
            return
        }
        disappearTime = nil
        
        if -time.timeIntervalSinceNow > (60 * 60 * 2.0) {
            self.tableView.mj_header.beginRefreshing()
        }
    }
}
