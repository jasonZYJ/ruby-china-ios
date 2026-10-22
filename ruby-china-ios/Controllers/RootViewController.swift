//
//  RootViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/8/2.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import SideMenu
import AMScrollingNavbar

class RootViewController: UITabBarController {
    
    fileprivate var isDidAppear = false
    fileprivate var needDisplayNotifications = false
    
    fileprivate func setupSideMenu() {
        SideMenuManager.default.leftMenuNavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "sideMenuController") as? SideMenuNavigationController
        SideMenuManager.default.menuPresentMode = .viewSlideOut
        SideMenuManager.default.menuAnimationBackgroundColor = UIColor.gray
        SideMenuManager.default.menuWidth = max(280, min(UIScreen.main.bounds.width * 0.8, 320))
    }

    fileprivate func setupSideMenuGesture() {
        // SideMenu 6 需手动添加屏幕边缘手势打开菜单（原版 SideMenu 2 自动添加，内部已去重）
        // 注意：首次 viewWillAppear 时 SceneDelegate 尚未调用 makeKeyAndVisible，keyWindow 为空
        guard let navigationController = UIApplication.appNavigationController else {
            return
        }
        _ = SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: navigationController.view, forMenu: .left)
    }
    
    fileprivate func setupViewControllers() {
        let topicsController = RootTopicsViewController()
        viewControllers = [topicsController]
    }
    
    @objc func displaySideMenu() {
        if let sideMenuController = SideMenuManager.default.leftMenuNavigationController {
            self.present(sideMenuController, animated: true, completion: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBar.isHidden = true
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem.fixNavigationSpacer(),
            UIBarButtonItem.narrowButtonItem(image: UIImage(named: "menu"), target: self, action: #selector(displaySideMenu))
        ]
        delegate = self
        setupSideMenu()
        setupViewControllers()
        
        resetNavigationItem(viewControllers![selectedIndex])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isDidAppear = true

        setupSideMenuGesture()

        if needDisplayNotifications {
            needDisplayNotifications = false
            displayNotifications()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 此窗口阶段 SceneDelegate 已 makeKeyAndVisible，补挂边缘手势
        setupSideMenuGesture()
    }
    
    fileprivate func resetNavigationItem(_ viewController: UIViewController) {
        navigationItem.title = viewController.navigationItem.title
        navigationItem.titleView = viewController.navigationItem.titleView
        navigationItem.rightBarButtonItems = viewController.navigationItem.rightBarButtonItems
    }
    
    func displayNotifications() {
        if !isDidAppear {
            needDisplayNotifications = true
            return
        }
        if !OAuth2.shared.isLogined {
            return
        }
        
        if presentedViewController != nil {
            dismiss(animated: false, completion: nil)
        }
        if let viewController = navigationController?.viewControllers.last {
            if viewController is NotificationsViewController {
                return
            }
            if viewController != self {
                _ = navigationController?.popToViewController(self, animated: false)
            }
        }
        
        navigationController?.pushViewController(NotificationsViewController(path: "/notifications"), animated: true)
    }
}

extension RootViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        resetNavigationItem(viewController)
    }
}
