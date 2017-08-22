//
//  DataSync+Cache.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 22/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileDataStore
import QMobileAPI
import Moya

protocol CacheTargetType: TargetType {
    var cacheFileName: String? { get }
}

extension TableTarget: CacheTargetType {

    var cacheFileName: String? {
        if name == TableTarget.allPath {
            return DataSync.Preferences.jsonTableExtension
        }
        return "\(name).\(DataSync.Preferences.jsonTableExtension)"
    }
}

extension RecordsTarget: CacheTargetType {

    var cacheFileName: String? {
        return "\(table).\(DataSync.Preferences.jsonDataExtension)"
    }

}

extension FileManager.SearchPathDirectory {

    var url: URL? {
        return try? FileManager.default.url(for: self, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}
extension URL {
    var fileExists: Bool {
        guard self.isFileURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: self.path)
    }
}
