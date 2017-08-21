//
//  DataSync+Records.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import Result
import Moya

import QMobileAPI
import QMobileDataStore

extension DataSync {

    typealias RecordInitializer = (String, JSON) -> Record?
    /// Initialize or find an existing record
    func recordInitializer(table: Table, context: DataStoreContext) -> RecordInitializer {
        let recordInitializer: RecordInitializer = { tableName, json in
            // Create only if not created
            if let predicate = table.predicate(for: json) {
                var record: Record?
                context.perform(wait: true) {
                    do {
                        record = try context.getOrCreate(in: tableName, matching: predicate)
                    } catch {
                        logger.warning("Failed to import one data into '\(tableName)': \(error)")
                    }
                }
                return record
            } else {
                logger.warning("Cannot insert record: Cannot create predicate for table '\(tableName)'")
            }
            return nil
        }
        return recordInitializer
    }

    /// Load records from files, need to be done in data store context
    func loadRecordsFromFile(saveByTable: Bool = true, context: DataStoreContext, save: @escaping () throws -> Swift.Void) throws {
        // Optionaly load data from files
        for (tableName, table) in self.tablesByName {
            if let url = self.bundle.url(forResource: tableName, withExtension: Preferences.jsonDataExtension, subdirectory: nil) {
                // XXX Could add here some decrypt or uncompress on JSON files if data encrypted or compressed
                let json = JSON(fileURL: url)
                assert(ImportableParser.tableName(for: json) == tableName)

                let records = try table.parser.parseArray(json: json, with: self.recordInitializer(table: table, context: context))
                logger.info("\(records.count) records imported from '\(tableName)' file")

                if saveByTable {
                    try save()
                }
            }
        }

        if !saveByTable {
            try save()
        }
    }

    // (a save publish information to UI)
    @discardableResult
    func trySave(_ save: @escaping () throws -> Swift.Void) -> Bool {
        do {
            try save()
            return true
        } catch {
            logger.warning("Failed to save some records: \(error)")
            return false
        }
    }

}
