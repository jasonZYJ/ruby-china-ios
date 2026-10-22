//
//  SceneDelegate.swift
//  ruby-china-ios
//
//  采用 UIScene 生命周期（iOS 26+ 强制要求）
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let rootViewController = RootViewController()
        let navigationController = ThemeNavigationController(rootViewController: rootViewController)
        navigationController.view.backgroundColor = UIColor.systemBackground

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        // 应用用户偏好的深浅色模式（跟随系统/浅色/深色）
        if let style = AppearanceMode.current.userInterfaceStyle {
            window?.overrideUserInterfaceStyle = style
        }
        window?.makeKeyAndVisible()

        // 冷启动时点击推送消息
        if AppDelegate.launchedFromRemoteNotification || connectionOptions.notificationResponse != nil {
            AppDelegate.launchedFromRemoteNotification = false
            rootViewController.displayNotifications()
        }
    }
}
