//
//  SideMenuViewController.swift
//  ruby-china-ios
//
//  Created by Jason Lee on 16/7/23.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import Kingfisher

class SideMenuViewController: UITableViewController {
    
    struct ItemData {
        let name: String
        let image: UIImage
        let imageColor: UIColor
        let actionURL: URL?
    }
    
    fileprivate lazy var router: Router = {
        let router = Router()
        router.bind("/logout") { (req) in
            OAuth2.shared.logout()
        }
        return router
    }()
    
    private lazy var datas = [[ItemData]]()
    private var headerView: UIView!
    private var logoView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 隐藏侧栏自带导航栏（原黑底区域），顶部改放 logo header
        navigationController?.setNavigationBarHidden(true, animated: false)
        edgesForExtendedLayout = .all
        view.backgroundColor = SIDEMENU_BG_COLOR

        NotificationCenter.default.addObserver(self, selector: #selector(refreshDatas), name: NSNotification.Name.userChanged, object: nil)
        refreshDatas()

        tableView.backgroundColor = SIDEMENU_BG_COLOR
        if #available(iOS 26.0, *) {
            // 玻璃卡片行自带边界，隐藏系统分隔线
            tableView.separatorStyle = .none
        }

        tableView.delegate = self
        tableView.dataSource = self

        // header 用 frame 布局；宽度在 viewDidLayoutSubviews 里按菜单实际宽度修正
        // （不能用约束把 tableHeaderView 锚定到 tableView 自身，会形成布局环导致崩溃）
        headerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        headerView.backgroundColor = SIDEMENU_BG_COLOR
        logoView = UIImageView(image: UIImage(named: "logo"))
        logoView.contentMode = .scaleAspectFit
        logoView.frame = CGRect(x: 110, y: 20, width: 100, height: 100)
        // 弹性左右边距：header 宽度变化时 logo 自动保持水平居中，不依赖布局时序
        logoView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        headerView.addSubview(logoView)

        let titleView = UILabel()
        titleView.text = "Ruby China"
        titleView.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleView.textColor = BLACK_COLOR
        titleView.textAlignment = .center
        titleView.frame = CGRect(x: 0, y: 128, width: 320, height: 30)
        // 与 logo 同步保持水平居中
        titleView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
        headerView.addSubview(titleView)
        tableView.tableHeaderView = headerView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        guard width > 0, headerView.bounds.width != width else {
            return
        }
        headerView.frame = CGRect(x: 0, y: 0, width: width, height: 200)
        // logo 与标题靠 autoresizing 弹性边距自动居中
        tableView.tableHeaderView = headerView
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return datas.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let itemData = datas[indexPath.section][indexPath.row]
        cell.textLabel!.text = itemData.name
        cell.imageView?.image = itemData.image
        cell.imageView?.tintColor = itemData.imageColor
        cell.selectionStyle = itemData.actionURL == nil ? .none : .blue
        attachGlassBackground(to: cell)
        return cell
    }

    /// iOS 26+：菜单项包 Liquid Glass 圆角卡片底（每行独立玻璃条，行间露出侧栏背景）
    fileprivate func attachGlassBackground(to cell: UITableViewCell) {
        guard #available(iOS 26.0, *) else {
            return
        }
        let glassTag = 1001
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        if let glass = cell.contentView.viewWithTag(glassTag) {
            // 复用时确保玻璃在最底层（文字图标在其上）
            cell.contentView.sendSubviewToBack(glass)
            return
        }
        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.tag = glassTag
        glass.isUserInteractionEnabled = false
        glass.layer.cornerRadius = 12
        glass.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(glass)
        cell.contentView.sendSubviewToBack(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 3),
            glass.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -3),
            glass.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 10),
            glass.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -10),
        ])
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 50
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let itemData = datas[indexPath.section][indexPath.row]
        if let url = itemData.actionURL {
            action(forURL: url)
        }
    }
    
}

// MARK: - action
@objc
extension SideMenuViewController {
    
    func refreshDatas() {
        datas.removeAll()
        
        if let user = OAuth2.shared.currentUser, OAuth2.shared.isLogined {
            datas.append([
                ItemData(
                    name: "title new topic".localized,
                    image: UIImage(named: "new")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/topics/new")!
                )
            ])
            
            datas.append([
                ItemData(
                    name: user.login,
                    image: UIImage(named: "profile")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/\(user.login)")!
                ),
                ItemData(
                    name: "edit account".localized,
                    image: UIImage(named: "edit-user")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/account/edit")!
                ),
                ItemData(
                    name: "favorites".localized,
                    image: UIImage(named: "favorites")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/topics/favorites")!
                ),
                ItemData(
                    name: "notes".localized,
                    image: UIImage(named: "notes")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/notes")!
                ),
                ItemData(
                    name: "sign out".localized,
                    image: UIImage(named: "logout")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/logout")!
                )
            ])
            let kUserSection = datas.count - 1
            // 下载用户头像
            let avatarSize = CGSize(width: 44, height: 44)
            let imageProcessor = RoundCornerImageProcessor(cornerRadius: avatarSize.width * 0.5, targetSize: avatarSize)
            KingfisherManager.shared.retrieveImage(with: .network(user.avatarUrl), options: [.processor(imageProcessor)], completionHandler: { [weak self] (result) in
                guard let self = self, case .success(let value) = result else {
                    return
                }
                let image = value.image
                guard let cgImage = image.cgImage else {
                    return
                }
                let avatarImage = UIImage(cgImage: cgImage, scale: 2, orientation: image.imageOrientation)
                let row = 0
                let oldData = self.datas[kUserSection][row]
                let newData = ItemData(name: oldData.name, image: avatarImage, imageColor: oldData.imageColor, actionURL: oldData.actionURL)
                self.datas[kUserSection][row] = newData
                let indexPath = IndexPath(row: row, section: kUserSection)
                self.tableView.reloadRows(at: [indexPath], with: .none)
            })
        } else {
            datas.append([
                ItemData(
                    name: "sign in".localized,
                    image: UIImage(named: "login")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/account/sign_in")!
                ),
                ItemData(
                    name: "sign up".localized,
                    image: UIImage(named: "profile")!.withRenderingMode(.alwaysTemplate),
                    imageColor: PRIMARY_COLOR,
                    actionURL: URL(string: "\(ROOT_URL)/account/sign_up")!
                )
            ])
        }
        
        datas.append([
            ItemData(
                name: "appearance mode".localized,
                image: UIImage(systemName: "circle.lefthalf.fill")?.withRenderingMode(.alwaysTemplate) ?? UIImage(),
                imageColor: PRIMARY_COLOR,
                actionURL: URL(string: "app://appearance")!
            ),
            ItemData(
                name: "wiki".localized,
                image: UIImage(named: "wiki")!.withRenderingMode(.alwaysTemplate),
                imageColor: PRIMARY_COLOR,
                actionURL: URL(string: "\(ROOT_URL)/wiki")!
            )
        ])
        
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        datas.append([
            ItemData(
                name: "copyright".localized,
                image: UIImage(named: "copyright")!.withRenderingMode(.alwaysTemplate),
                imageColor: PRIMARY_COLOR,
                actionURL: URL(string: COPYRIGHT_URL)!
            ),
            ItemData(
                name: "v\(APP_VERSION) (build \(build))",
                image: UIImage(named: "versions")!.withRenderingMode(.alwaysTemplate),
                imageColor: PRIMARY_COLOR,
                actionURL: nil
            )
        ])
        
        self.tableView.reloadData()
    }
    
}

// MARK: - private
@objc
extension SideMenuViewController {
    
    fileprivate func action(forURL url: URL) {
        // App 内部动作（深浅色模式等）
        if url.scheme == "app" {
            if url.host == "appearance" {
                presentAppearancePicker()
            }
            return
        }
        guard let host = url.host else {
            return
        }
        if host != URL(string: ROOT_URL)!.host! {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if router.match(URL(string: url.path)!) == nil {
            dismiss(animated: true, completion: {
                if let host = url.host, host != URL(string: ROOT_URL)!.host! {
                    TurbolinksSessionLib.shared.safariOpen(url)
                } else {
                    TurbolinksSessionLib.shared.action(.Advance, path: url.path)
                }
            })
        }
    }

    /// 深浅色模式三选一（跟随系统/浅色/深色），立即生效
    fileprivate func presentAppearancePicker() {
        let alert = UIAlertController(title: "appearance mode".localized, message: nil, preferredStyle: .actionSheet)
        let modes: [AppearanceMode] = [.system, .light, .dark]
        let current = AppearanceMode.current
        for mode in modes {
            let title = mode == current ? "✓ " + mode.localizedTitle : mode.localizedTitle
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                AppearanceMode.set(mode)
            })
        }
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil))
        // iPad 上 actionSheet 必须有 sourceView
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1)
        }
        present(alert, animated: true, completion: nil)
    }

}
