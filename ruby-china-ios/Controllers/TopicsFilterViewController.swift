//
//  TopicsFilterViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/22.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit

class TopicsFilterViewController: UIViewController {
    
    enum NodeData {
        case listType(TopicsService.ListType)
        case node(id: Int, name: String)
        
        func getName() -> String {
            switch self {
            case let .listType(type):
                switch type {
                case .last_actived  : return "默认"
                case .recent        : return "最新发布"
                case .no_reply      : return "无人问津"
                case .popular       : return ""
                case .excellent     : return "优质帖子"
                }
            case let .node(_, name):
                return name
            }
        }
    }
    
    var selectedData: NodeData?
    var onChangeSelect: ((TopicsFilterViewController) -> ())?
    
    private struct GroupData {
        let name: String
        let nodes: [NodeData]
    }
    
    private let kHeaderIdentifier = "HEADERVIEW"
    private let kCellIdentifier = "NODECELL"
    private var groupDatas = [GroupData]()

    private lazy var collectionView: UICollectionView = {
        let colNumber: CGFloat = 4
        let cellMargin: CGFloat = 10
        let cellWidth = (self.view.bounds.size.width - (colNumber + 1) * cellMargin) / colNumber
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: floor(cellWidth), height: 30)
        layout.minimumLineSpacing = cellMargin
        layout.minimumInteritemSpacing = cellMargin
        layout.sectionInset = UIEdgeInsets(top: cellMargin, left: cellMargin, bottom: cellMargin, right: cellMargin)
        layout.headerReferenceSize = CGSize(width: self.view.bounds.size.width, height: 30)
        
        let view = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = UIColor.clearColor()
        view.registerClass(TopicsFilterNodeCell.self, forCellWithReuseIdentifier: self.kCellIdentifier)
        view.registerClass(TopicsFilterNodeSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: self.kHeaderIdentifier)
        return view
    }()
    
    private lazy var cellSelectedImage: UIImage? = {
        let cellSize = (self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        return UIImage.roundedCorner(imageSize: cellSize, radius: 5, backgroundColor: NAVBAR_BG_COLOR, borderWidth: 0, borderColor: NAVBAR_BG_COLOR)
    }()
    private lazy var cellNormalImage: UIImage? = {
        let cellSize = (self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        return UIImage.roundedCorner(imageSize: cellSize, radius: 5, backgroundColor: UIColor.clearColor(), borderWidth: 1, borderColor: SEGMENT_BG_COLOR)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initGroupDatas()
        
        view.backgroundColor = UIColor(white: 1, alpha: 0.9)
        view.addSubview(collectionView)
        collectionView.snp_makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        loadNodes()
    }

}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension TopicsFilterViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return groupDatas.count
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return groupDatas[section].nodes.count
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: kHeaderIdentifier, forIndexPath: indexPath) as! TopicsFilterNodeSectionHeaderView
            view.name = groupDatas[indexPath.section].name
            return view
        }
        return UICollectionReusableView()
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let node = groupDatas[indexPath.section].nodes[indexPath.item]
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(kCellIdentifier, forIndexPath: indexPath) as! TopicsFilterNodeCell
        cell.normalImage = cellNormalImage
        cell.selectedImage = cellSelectedImage
        cell.name = node.getName()
        cell.selected = selectedData == nil ? false : node == selectedData!
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let node = groupDatas[indexPath.section].nodes[indexPath.item]
        selectedData = node
        onChangeSelect?(self)
    }
    
}

// MARK: - private

extension TopicsFilterViewController {
    
    private func initGroupDatas() {
        let nodes = [
            NodeData.listType(.last_actived),
            NodeData.listType(.excellent),
            NodeData.listType(.no_reply),
            NodeData.listType(.recent),
        ]
        groupDatas.append(GroupData(name: "所有帖子", nodes: nodes))
    }
    
    private func loadNodes() {
        NodesService.list { [weak self] (statusCode, result) in
            if let nodes = result {
                self?.addDatas(nodes: nodes)
            }
        }
    }
    
    private func addDatas(nodes nodes: [Node]) {
        if nodes.count <= 0 {
            return
        }
        
        let selectedData = self.selectedData
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            
            var scrollToIndexPath: NSIndexPath?
            var addGroupDatas = [GroupData]()
            
            let sortNodes = nodes.sort {
                $0.sectionName != $1.sectionName ? $0.sectionName < $1.sectionName : $0.name < $1.name
            }
            
            var nodeList = [NodeData]()
            var prevSectionName = sortNodes.first!.sectionName
            for node in sortNodes {
                if node.sectionName != prevSectionName {
                    addGroupDatas.append(GroupData(name: prevSectionName, nodes: nodeList))
                    nodeList = [NodeData]()
                    prevSectionName = node.sectionName
                }
                
                let nodeData = NodeData.node(id: node.id, name: node.name)
                if scrollToIndexPath == nil && selectedData != nil && selectedData! == nodeData {
                    scrollToIndexPath = NSIndexPath(forItem: nodeList.count, inSection: addGroupDatas.count + 1)
                }
                nodeList.append(nodeData)
            }
            if nodeList.count > 0 {
                addGroupDatas.append(GroupData(name: prevSectionName, nodes: nodeList))
            }
            
            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                self?.groupDatas += addGroupDatas
                self?.collectionView.reloadData()
                if let indexPath = scrollToIndexPath {
                    self?.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .CenteredVertically, animated: false)
                }
            }
        }
    }
    
}

// MARK: - 重载运算符

func ==(v1: TopicsFilterViewController.NodeData, v2: TopicsFilterViewController.NodeData) -> Bool {
    switch (v1, v2) {
    case let (.listType(type1), .listType(type2)) where type1 == type2:
        return true
    case let (.node(id1, _), .node(id2, _)) where id1 == id2:
        return true
    default: return false
    }
}
