//
//  DataSync+Dump.swift
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
import CoreData

extension DataSync {

    public func dump(to path: Path, with contextType: DataStoreContextType = .background, wait: Bool = false, completion: @escaping (Result<[String], NSError>) -> Void) -> Bool {
        assert(path.isWritable)

        if !path.exists {
            try? path.createDirectory(withIntermediateDirectories: true)
        }

        return self.dataStore.perform(contextType, wait: wait, blockName: "dump") { context in

            var results = [[String: Any]]()

            context.dump { table, result in

                let file = path + "\(table.name).json"

                var dico = [String: Any]()
                switch result {
                case .success(let records):
                    dico["success"] = true
                    //dico["table"] = table.dictionary
                    dico["records"] = records.map { (object: Record) -> [String: Any] in
                        let keys = table.fields.map { $0.name }
                        var objectDico: [String: Any] = object.dictionaryWithValues(forKeys: keys).compactMapValues { $0 }

                        for dateKey in table.fields.filter({ $0.type == .date }).map({ $0.name }) {
                            if let date = objectDico[dateKey] as? Date {
                                objectDico[dateKey] = DateFormatter.iso8601.string(from: date)
                            }
                        }
                        let relationKeys = table.relationships.map({ $0.name })
                        let relationDico: [String: Any] = object.dictionaryWithValues(forKeys: relationKeys).mapValues({ relationValue in
                            if let record = relationValue as? RecordBase {
                                return "\(record.objectID)"
                            } else if let records = relationValue as? Set<RecordBase> {
                                return records.compactMap({ "\($0.objectID)" })
                            }
                            return nil
                        }).compactMapValues { $0 }

                        // combine
                        return objectDico.merging(relationDico) { (current, _) in current }
                    }
                case .failure(let error):
                    dico["success"] = false
                    // dico["table"] = table.dictionary
                    dico["errors"] = error.errors
                }
                do {
                    if file.exists {
                        try file.deleteFile()
                    }

                    /*  if JSONSerialization.isValidJSONObject(dico) {*/
                    let rawData = try JSONSerialization.data(withJSONObject: dico, options: .prettyPrinted)
                    try rawData.write(to: file.url)
                    logger.info("Data of table \(table.name) dumped into \(file)")
                    /* } else {
                     logger.warning("Failed to dump data of table \(table.name) into \(file): invalid json")
                     dico["errors"]  = "invalid json"
                     }*/
                } catch {
                    logger.warning("Failed to dump data of table \(table.name) into \(file): \(error)")
                    dico["errors"]  = "\(error)"
                }
                results.append(dico)
            }

            // try a copy of db instead of converting to json, work only for core data
            do {
                if let container = ((self.dataStore) as? CoreDataStore)?.persistentContainer,
                    let storeURL = container.persistentStoreDescriptions.first?.url,
                    let storePath = Path(url: storeURL) {
                    let dst = path + storePath.fileName
                    if dst.exists {
                        try dst.deleteFile()
                    }

                    try storePath.copyFile(to: dst)

                    let tableNames: [String] = context.tablesInfo.map { $0.name}
                    // let tableNames = results.filter({ $0["errors"] == nil }).compactMap({ $0["table"] as? [String: Any] }).compactMap({ $0["name"] as? String })

                    //if tableNames.count == results.count {
                    completion(.success(tableNames))

                } else {
                    completion(.failure(NSError(domain: "com.4d.mobile", code: 2, userInfo: ["message": "unable to find database to dump"])))

                }
            } catch let error as NSError {
                completion(.failure(error))
            } catch {
                completion(.failure(NSError(domain: "com.4d.mobile", code: 1, userInfo: ["message": "\(error)"])))
            }
            /* } else {
             completion(.failure(DataSyncDumpError.failedToDump(results)))
             }*/

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
        dico["name"] = self.name as NSString
        dico["fields"] = self.fields.map { $0.dictionary /*as NSDictionary*/ } /*as NSArray*/
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
        if let userInfo = self.userInfo as? [String: Any] {
            dico["userInfo"] = userInfo
        }
        dico["type"] = self.type.rawValue

        return dico
    }
    public var json: JSON {
        return JSON(self.dictionary)
    }
}
