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
import FileKit

/// A target which provide a name for a cache file.
protocol CacheTargetType: TargetType {
    /// Name of the cache file.
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

extension DataSync {

    /// Clear all cache files.
    public func clearFileCache() {
        let files = self.cachePath.children().filter { $0.pathFullExtension == DataSync.Preferences.jsonDataExtension }
        for file in files where file.exists {
            try? file.deleteFile()
        }
    }

    /// Remove all records cache files according to list of table.
    func deleteRecordsCacheFile() throws {
        for (table, _) in self.tablesInfoByTable {
            let tableName = table.name
            let file: Path = self.cachePath + "\(tableName).\(Preferences.jsonDataExtension)"
            if file.exists {
                try? file.deleteFile()
            }
        }
    }

    func moveToCache(from tempPath: Path) throws {
        let files = tempPath.children().filter { $0.pathFullExtension == DataSync.Preferences.jsonDataExtension }
        self.clearFileCache()
        let cachePath = self.cachePath
        for file in files {
            let destination: Path = cachePath + file.fileName
            try file.copyFile(to: destination)
        }
    }
}

extension JSON {
    init(path: Path) throws {
        try self.init(fileURL: path.url)
    }
}

extension Path {
    public var pathFullExtension: String? {
        var components = self.rawValue.components(separatedBy: ".")
        guard components.count > 1 else {
            return nil
        }
        components.removeFirst()
       return components.joined(separator: ".")
    }
}
