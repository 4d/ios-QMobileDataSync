//
//  DataSync+Dumpswift.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 12/09/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore
import QMobileAPI
import SwiftyJSON
import FileKit

extension DataSync {

    public func dump(to path: Path, with contextType: DataStoreContextType = .background, wait: Bool = false, completion: @escaping () -> Void) -> Bool {
        assert(path.isWritable)

        return self.dataStore.perform(contextType, wait: wait) { context, _ in

            context.dump { table, result in

                let file = path + "\(table.name).json"

                var dico = [String: Any]()
                switch result {
                case .success(let records):
                    dico["success"] = true
                    dico["table"] = table.dictionary
                    dico["records"] = records.map { $0.dictionaryWithValues(forKeys: table.fields.map { $0.name }) }
                case .failure(let error):
                    dico["success"] = false
                    dico["errors"] = error.errors
                }
                do {
                    if file.exists {
                        try file.deleteFile()
                    }
                    // FIXME: cannot json encode with some value type like optionnal...
                    // JSONEncoder().encode(dico)
                    let data = try JSON(dico).rawData()
                    try DataFile(path: file).write(data)
                    logger.info("Data of table \(table.name) dumped into \(file)")
                } catch {
                    logger.warning("Failed to dump data of table \(table.name) into \(file): \(error)")
                }
            }
            completion()
        }

    }
}

extension DataStoreError {
    public var errorStack: [Swift.Error] {
        let error = self.error
        var stack: [Swift.Error] = [error]
        if let error = error as? ErrorWithCause {
            if let toAppend = error.errorStack {
                stack.append(contentsOf: toAppend)
            }
        } else if let error = error.userInfoUnderlyingError {
            stack.append(error)
        }
        return stack
    }

    public var errors: [[String: Any]] {
        var errors = [[String: Any]]()
        for error in errorStack {
            errors.append(["message": error.localizedDescription])
        }
        return errors
    }
}
// CLEAN: remove folloing code, use one from API framewoek
extension Swift.Error {

    var userInfoUnderlyingError: Swift.Error? {
        if let error = self as? CustomNSError {
            return error.errorUserInfo[NSUnderlyingErrorKey] as? Swift.Error
        }
        if let underlyingError = (self as NSError).userInfo[NSUnderlyingErrorKey] as? Swift.Error {
            return underlyingError
        }
        return nil
    }
}

extension DataStoreTableInfo {

    public var dictionary: [String: Any] {
        var dico = [String: Any]()
        dico["name"] = self.name
        dico["fields"] = self.fields.map { $0.dictionary }
         return dico
    }
    public var json: JSON {
        return JSON(self.dictionary)
    }
}

extension DataStoreFieldInfo {

    public var dictionary: [String: Any] {
        var dico = [String: Any]()
        dico["name"] = self.name
        dico["localizedName"] = self.localizedName
        dico["isOptional"] = self.isOptional
        if let userInfo = self.userInfo {
            dico["userInfo"] = userInfo
        }
        dico["type"] = self.type

        return dico
    }
    public var json: JSON {
        return JSON(self.dictionary)
    }
}
