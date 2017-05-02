//
//  DataSync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 02/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore
import QMobileAPI

let logger = Logger.forClass(DataSync.self)

public class DataSync {

    static let kJSONDataExtension = "data.json"
    static let kJSONTableExtension = "catalog.json"

    public let rest: APIManager = APIManager.instance
    public let dataStore: DataStore = QMobileDataStore.dataStore

    /// Bundle for files
    public var bundle: Bundle = .main
    /// List of loaded tables indexed by name
    public var tables: [String: Table] = [:]

    public func loadTable() {
        // from files, extension = catalog.json
        logger.debug("Read table structures")
        var tables = [String: Table]()
        if let tableStructures = bundle.urls(forResourcesWithExtension: DataSync.kJSONDataExtension, subdirectory: nil) {
            for tableStructure in tableStructures {
                if let table = Table(fileURL: tableStructure) {
                    tables[table.name] = table
                }
            }
        }
        logger.info("Table strutures read: \(Array(tables.keys))")

        // from remote store?
        _ = rest.loadTables { result in
            switch result {
            case .success(_):
                // Could check if all table accessible on remote target
                break
            case .failure(let error):
                logger.warning("Failed to retrieve \(error)")
            }
        }
    }

    typealias RecordInitializer = (String, JSON) -> Record?
    func recordInitializer(table: Table, context: DataStoreContext) -> RecordInitializer {
        let recordInitializer: RecordInitializer = { tableName, json in
            if let predicate = table.predicate(for: json) {
                 do {
                 return try context.getOrCreate(in: tableName, matching: predicate)
                 } catch {
                 logger.warning("Failed to import into '\(tableName)': \(error)")
                 }
            } else {
                logger.warning("Cannot insert record: Cannot create predicate for table '\(tableName)'")
            }
            return nil
        }
        return recordInitializer
    }

    public func cancel() {
        // TODO cancel all requests, or return a cancellable object in sync function
    }

    public func sync() {
        // TODO add an handler for completion and maybe progress
        // TODO If there is already a sync stop it, maybe add a bool force and only if force=true, or do nothing

        // TODO get last stamp from dataStore metadata

        let perform = dataStore.perform(.background) { context, save in

            // TODO for each table get data from last global stamp
            // If no stamp and dataStore empty get from files?
            // If no stamp get all
            for (tableName, table) in self.tables {

                // from remote
                _ = self.rest.loadRecords(table: table, initializer: self.recordInitializer(table: table, context: context)) { result in
                    switch result {
                    case .success(let (records, page)):

                        // TODO if last page, save? or save each for each page(option)
                        if page.isLast {

                            self.dataStore.save { _ in
                                
                            }
                        }
                        // TODO check/save global stamp and current one
                        // TODO save in data store records?

                        break
                    case .failure(let error):
                        logger.warning("Failed to get records: \(error)")
                    }
                }

                // from files
                if let url = self.bundle.url(forResource: tableName, withExtension: DataSync.kJSONDataExtension, subdirectory: nil) {
                    let json = JSON(fileURL: url)
                    assert(ImportableParser.tableName(for: json) == tableName)
                }
            }
        }

        if !perform {
            logger.warning("Cannot get data: context cannot be created on data store")
        }

        /*
         if let tableData = Bundle.main.urls(forResourcesWithExtension: "data.json", subdirectory: nil) {
         for tableDatum in tableData {
         let json = JSON(fileURL: tableDatum)
         if let tableName = ImportableParser.tableName(for: json) {
                    
                    if let table = tables[tableName] {
                        
                        let perform = dataStore.perform(.background, { context, save in
                            
                            let records = table.parser.parse(json: json, with: { tableName, json in
         
                                
                                if let predicate = table.predicate(for: json) {
                                    do {
                                        return try context.getOrCreate(in: tableName, matching: predicate)
                                    } catch {
                                        logger.warning("Failed to import into '\(tableName)': \(error)")
                                    }
                                }
                                return nil
                            })
                            
                            logger.info("\(records.count) records imported from '\(tableName)' data")
                            
                            do {
                                let count = try dataStore.fetchRequest(tableName: tableName).count(context: context)
                                logger.info("\(count) records into table '\(tableName)'")
                            } catch {
                                logger.warning("Failed to count total records into table '\(tableName)': \(error)")
                            }
                            
                            do {
                                try save()
                                logger.info("Mobile database has been saved after importing '\(tableName)'")
                            } catch {
                                alert(title: "Failed to save mobile database after importing '\(tableName)'", error: error)
                            }
                        })
                        
                        if !perform {
                            logger.warning("Cannot enqueue task to import table '\(tableName)' data")
                        }
                        
                    } else {
                        logger.warning("There is no table structure definition for table \(tableName). Could not load associated data")
                    }
                    
                } else {
                    logger.warning("There is no table name into table data file '\(tableDatum)'.")
                }
            }
        }*/

    }

}
