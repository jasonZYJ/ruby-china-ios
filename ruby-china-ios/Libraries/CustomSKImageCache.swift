//
//  CustomSKImageCache.swift
//  ruby-china-ios
//
//  Created by kelei on 16/10/27.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import SKPhotoBrowser
import Kingfisher

class CustomImageCache: SKImageCacheable {
    fileprivate let cache = KingfisherManager.shared.cache

    func imageForKey(_ key: String) -> UIImage? {
        if let memoryImage = cache.retrieveImageInMemoryCache(forKey: key) {
            return memoryImage
        }
        guard let data = try? cache.diskStorage.value(forKey: key) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        cache.store(image, forKey: key)
    }
    
    func removeImageForKey(_ key: String) {
        cache.removeImage(forKey: key)
    }
    
    func removeAllImages() {
        cache.clearMemoryCache()
        cache.clearDiskCache()
    }
    
}
