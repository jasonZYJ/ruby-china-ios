//
//  RBTextField.swift
//  ruby-china-ios
//
//  Created by Jason Lee on 16/7/26.
//  Copyright © 2016年 ruby-china. All rights reserved.
//
import UIKit

@IBDesignable
class RBTextField: UITextField {
    fileprivate let border = CALayer()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupView()
    }

    func setupView() {
        self.borderStyle = UITextField.BorderStyle.none
        self.layer.addSublayer(border)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 动态分隔线颜色：跟随深浅色模式（CALayer 不会自动解析动态色，需在布局时解析）
        border.backgroundColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
        border.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
    }
}
