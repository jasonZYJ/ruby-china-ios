//
//  QuickActionsPanel.swift
//  ruby-china-ios
//
//  右下角毛玻璃浮动快捷组（垂直排列）：文字/图标按钮 + 分隔线，
//  深浅色自动适配，半透明不影响阅读
//

import UIKit

class QuickActionsPanel: UIVisualEffectView {

    struct Item {
        var title: String? = nil
        var systemIcon: String? = nil
        /// [weak self] 捕获，避免面板持有页面造成循环引用
        var action: () -> Void
    }

    fileprivate var actionMap: [UIControl: () -> Void] = [:]

    init(items: [Item]) {
        // Liquid Glass 质感保留；UIGlassEffect 本体透明度偏低（挡内容），
        // 用整体 alpha 降到 0.82 折中：玻璃感在、又能隐约透出底下内容
        if #available(iOS 26.0, *) {
            super.init(effect: UIGlassEffect())
            alpha = 0.82
            // glass 自带形状渲染，clip 会破坏折射边缘
            clipsToBounds = false
        } else {
            super.init(effect: UIBlurEffect(style: .systemThinMaterial))
            clipsToBounds = true
            layer.borderWidth = 0.5
            layer.borderColor = UIColor.separator.cgColor
        }
        layer.cornerRadius = 22

        var arranged: [UIView] = []
        for (index, item) in items.enumerated() {
            if index > 0 {
                arranged.append(makeDivider())
            }
            let button: UIButton
            if let title = item.title {
                button = makeTitleButton(title)
            } else {
                button = makeIconButton(item.systemIcon!)
            }
            actionMap[button] = item.action
            arranged.append(button)
        }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 固定在目标 view 右下角
    func pinToBottomRight(of view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            widthAnchor.constraint(equalToConstant: 52),
        ])
    }

    fileprivate func makeTitleButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(PRIMARY_COLOR, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        style(button)
        return button
    }

    fileprivate func makeIconButton(_ systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        // 与文字按钮同尺寸（16 semibold），视觉重量一致
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = PRIMARY_COLOR
        style(button)
        return button
    }

    fileprivate func style(_ button: UIButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.addTarget(self, action: #selector(tapAction(_:)), for: .touchUpInside)
    }

    fileprivate func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    @objc fileprivate func tapAction(_ sender: UIButton) {
        actionMap[sender]?()
    }
}
