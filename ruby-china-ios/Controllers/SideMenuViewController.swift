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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 隐藏侧栏自带导航栏（原黑底区域），顶部改放 logo header
        navigationController?.setNavigationBarHidden(true, animated: false)
        edgesForExtendedLayout = .all
        view.backgroundColor = SIDEMENU_BG_COLOR

        NotificationCenter.default.addObserver(self, selector: #selector(refreshDatas), name: NSNotification.Name.userChanged, object: nil)
        refreshDatas()

        tableView.backgroundColor = SIDEMENU_BG_COLOR

        tableView.delegate = self
        tableView.dataSource = self

        // table header 用约束锚定到 tableView 宽度，避免 present 前取到错误 bounds 导致 logo 偏出屏幕
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = SIDEMENU_BG_COLOR
        let logoView = UIImageView(image: UIImage(named: "logo"))
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 35),
            logoView.widthAnchor.constraint(equalToConstant: 100),
            logoView.heightAnchor.constraint(equalToConstant: 100),
            headerView.topAnchor.constraint(equalTo: tableView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 170),
        ])
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
        return cell
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
    
}
