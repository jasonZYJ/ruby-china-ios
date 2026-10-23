//
//  TopicCell.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/12.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import SnapKit
import Kingfisher

private let kContentPadding = UIEdgeInsets(top: 15, left: 25, bottom: 15, right: 25)
private let kTitleTextSize: CGFloat = 16
private let kTextSize: CGFloat = 14
private let kSummaryTextSize: CGFloat = 13
private let kTextFont = UIFont.systemFont(ofSize: kTextSize, weight: UIFont.Weight.regular)
private let kTitleTextFont = UIFont.systemFont(ofSize: kTitleTextSize, weight: UIFont.Weight.medium)
private let kAvatarSize = CGSize(width: 18, height: 18)
private let kAvatarColor = dynamicColor(light: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
                                        dark: UIColor(white: 0.62, alpha: 1.0))
private let kNodeColor = dynamicColor(light: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
                                      dark: UIColor(white: 0.62, alpha: 1.0))
private let kSummaryColor = dynamicColor(light: UIColor(white: 0.45, alpha: 1.0),
                                         dark: UIColor(white: 0.62, alpha: 1.0))
/// 精华帖奖章图标颜色（橙红）
private let kExcellentColor = UIColor(red: 0.91, green: 0.33, blue: 0.22, alpha: 1.0)

class TopicCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        attachGlassBackground()
        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(summaryLabel)
        contentView.addSubview(repliesCountLabel)
        contentView.addSubview(nodeButton)
        contentView.addSubview(userNameButton)
        setupConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var fontScale: CGFloat = 1 {
        didSet {
            guard fontScale != oldValue else {
                return
            }
            applyFonts()
            refreshContent()
        }
    }

    var data: Topic? {
        didSet {
            refreshContent()
        }
    }

    /// 正文摘要（标题下方两行）；为 nil 时隐藏该行
    var summary: String? {
        didSet {
            refreshContent()
        }
    }

    fileprivate func refreshContent() {
        if let data = data {
            let avatarSize = CGSize(width: kAvatarSize.width * 2, height: kAvatarSize.height * 2)
            let imageProcessor = RoundCornerImageProcessor(cornerRadius: avatarSize.width / 2.0, targetSize: avatarSize)
            avatarImageView.kf.setImage(with: data.user.avatarUrl, options: [
                .processor(imageProcessor),
                .transition(ImageTransition.fade(0.5))
            ])

            titleLabel.attributedText = titleAttributedText(data)
            summaryLabel.text = summary
            repliesCountLabel.text = data.repliesCount > 0 ? "\(data.repliesCount)" : nil
            nodeButton.setTitle(data.nodeName, for: .normal)
            userNameButton.setTitle(data.user.login, for: .normal)
        } else {
            avatarImageView.kf.setImage(with: nil as URL?)
            titleLabel.attributedText = nil
            summaryLabel.text = nil
            repliesCountLabel.text = nil
            nodeButton.setTitle(nil, for: .normal)
            userNameButton.setTitle(nil, for: .normal)
        }
    }

    fileprivate func applyFonts() {
        titleLabel.font = UIFont.systemFont(ofSize: kTitleTextSize * fontScale, weight: UIFont.Weight.medium)
        let textFont = UIFont.systemFont(ofSize: kTextSize * fontScale, weight: UIFont.Weight.regular)
        summaryLabel.font = UIFont.systemFont(ofSize: kSummaryTextSize * fontScale, weight: UIFont.Weight.regular)
        userNameButton.titleLabel?.font = textFont
        nodeButton.titleLabel?.font = textFont
        repliesCountLabel.font = textFont
    }
    
    var onUserClick: ((_ data: Topic?) -> ())? {
        didSet {
            avatarImageView.isUserInteractionEnabled = onUserClick != nil
            userNameButton.isEnabled = onUserClick != nil
        }
    }
    var onNodeClick: ((_ data: Topic?) -> ())? {
        didSet {
            nodeButton.isEnabled = onNodeClick != nil
        }
    }
    
    fileprivate lazy var avatarImageView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userAction)))
        return view
    }()
    fileprivate lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = dynamicColor(light: UIColor(white: 0.13, alpha: 1), dark: UIColor(white: 0.95, alpha: 1))
        view.numberOfLines = 0
        return view
    }()
    fileprivate lazy var summaryLabel: UILabel = {
        let view = UILabel()
        view.textColor = kSummaryColor
        view.font = UIFont.systemFont(ofSize: kSummaryTextSize, weight: UIFont.Weight.regular)
        view.numberOfLines = 2
        return view
    }()
    fileprivate lazy var repliesCountLabel: UILabel = {
        let view = UILabel()
        view.textColor = dynamicColor(light: UIColor(white: 0.4, alpha: 1), dark: UIColor(white: 0.65, alpha: 1))
        view.font = kTextFont
        view.textAlignment = .right
        return view
    }()
    fileprivate lazy var nodeButton: UIButton = {
        let view = UIButton()
        view.titleLabel?.font = kTextFont
        view.setTitleColor(kNodeColor, for: .normal)
        view.addTarget(self, action: #selector(nodeAction), for: .touchUpInside)
        view.isEnabled = false
        return view
    }()
    fileprivate lazy var userNameButton: UIButton = {
        let view = UIButton()
        view.titleLabel?.font = kTextFont
        view.setTitleColor(kAvatarColor, for: .normal)
        view.addTarget(self, action: #selector(userAction), for: .touchUpInside)
        view.isEnabled = false
        return view
    }()
    
}

// MARK: - action
@objc
extension TopicCell {
    
    func userAction() {
        if let action = onUserClick {
            action(data)
        }
    }
    
    func nodeAction() {
        if let action = onNodeClick {
            action(data)
        }
    }
    
}

// MARK: - private

extension TopicCell {

    /// iOS 26+：文章卡片包 Liquid Glass 圆角底（与侧栏菜单一致），行间自然露出背景形成间距
    fileprivate func attachGlassBackground() {
        guard #available(iOS 26.0, *) else {
            return
        }
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.isUserInteractionEnabled = false
        glass.layer.cornerRadius = 14
        glass.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glass)
        contentView.sendSubviewToBack(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            glass.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            glass.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            glass.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    
    fileprivate func setupConstraints() {
        avatarImageView.snp.makeConstraints { (make) in
            make.left.top.equalToSuperview().inset(kContentPadding)
            make.size.equalTo(kAvatarSize)
        }
        userNameButton.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView.snp.right).offset(6)
            make.centerY.equalTo(avatarImageView)
        }
        nodeButton.snp.makeConstraints { (make) in
            make.right.top.equalToSuperview().inset(kContentPadding)
            make.centerY.equalTo(avatarImageView)
        }
        titleLabel.snp.makeConstraints { (make) in
            make.left.equalTo(avatarImageView)
            make.right.equalTo(repliesCountLabel.snp.left)
            make.top.equalTo(avatarImageView.snp.bottom).offset(5)
        }
        summaryLabel.snp.makeConstraints { (make) in
            make.left.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().inset(kContentPadding)
        }
        // 摘要为空（nil）时不能把行高撑高：压缩到 0
        summaryLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        summaryLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        repliesCountLabel.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel)
            make.right.equalToSuperview().inset(kContentPadding)
            make.width.equalTo(44)
        }
    }
    
    fileprivate func titleAttributedText(_ data: Topic) -> NSAttributedString {
        let titleFont = UIFont.systemFont(ofSize: kTitleTextSize * fontScale, weight: UIFont.Weight.medium)
        let attributes = [NSAttributedString.Key.font : titleFont]
        let attributedString = NSMutableAttributedString(string: data.title, attributes: attributes)

        func addIcon(systemName: String, color: UIColor = kNodeColor) {
            // SF Symbol 转换有开销，按深浅色+字号+颜色各缓存一份避免滚动时重复生成
            guard let attachment = TopicCell.iconAttachment(systemName, color: color, for: traitCollection.userInterfaceStyle, size: kTitleTextSize * fontScale) else {
                return
            }
            attributedString.append(NSAttributedString(attachment: attachment))
        }

        if data.excellent {
            // 精华帖：橙红奖章图标（rosette），iOS 16 以下无此符号回退印章
            let symbolName = UIImage(systemName: "rosette") != nil ? "rosette" : "seal.fill"
            addIcon(systemName: symbolName, color: kExcellentColor)
        }
        if data.closedAt != nil {
            addIcon(systemName: "checkmark.circle.fill")
        }

        return attributedString
    }

    private static var iconAttachments: [UIUserInterfaceStyle: [String: NSTextAttachment]] = [:]
    private static func iconAttachment(_ systemName: String, color: UIColor, for style: UIUserInterfaceStyle, size: CGFloat) -> NSTextAttachment? {
        let cacheKey = "\(systemName)-\(color.description)-\(Int(size * 10))"
        if let cached = iconAttachments[style]?[cacheKey] {
            return cached
        }
        let resolvedColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        guard let image = UIImage(systemName: systemName)?
            .withTintColor(resolvedColor, renderingMode: .alwaysOriginal) else {
            return nil
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -2, width: size * 0.9, height: size * 0.9)
        iconAttachments[style, default: [:]][cacheKey] = attachment
        return attachment
    }

}
