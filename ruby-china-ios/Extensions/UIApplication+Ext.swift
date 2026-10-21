//
//  UIApplication+Ext.swift
//  hlios-ios
//
//  Created by kelei on 16/7/27.
//  Copyright © 2016年 Huacnlee. All rights reserved.
//

import UIKit

extension UIApplication {

    /// 兼容 Scene 生命周期的主窗口
    static var keyWindow: UIWindow? {
        let foregroundScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        for scene in foregroundScenes {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }
        return foregroundScenes.flatMap { $0.windows }.first
    }

    /**
     获取应用当前看到的ViewController

     - returns: 正在显示的ViewController
     */
    static func currentViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.keyWindow?.rootViewController else {
            return nil
        }
        return findBestViewController(rootViewController)
    }
    static fileprivate func findBestViewController(_ viewController: UIViewController) -> UIViewController {
        if let vc = viewController.presentedViewController {
            // Return presented view controller
            return findBestViewController(vc)
        } else if let svc = viewController as? UISplitViewController , svc.viewControllers.count > 0 {
            // Return right hand side
            return findBestViewController(svc.viewControllers.last!)
        } else if let nc = viewController as? UINavigationController , nc.viewControllers.count > 0 {
            // Return top view
            return findBestViewController(nc.viewControllers.last!)
        } else if let tbc = viewController as? UITabBarController, let vc = tbc.selectedViewController {
            // Return visible view
            return findBestViewController(vc)
        }
        // Unknown view controller type, return last child view controller
        return viewController
    }

}
