//
//  DataStore+API.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 11/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore

extension DataStoreContext {
    
    public func create(in table: Table) -> Record? {
        return create(in: table.name)
    }

    public func getOrCreate(in table: Table, matching predicate: NSPredicate) throws -> Record? {
        return try getOrCreate(in: table.name, matching: predicate)
    }
    
    /// Create and updates values
    public func insert(in table: Table, values: [String : Any]) -> Record? {
        return insert(in: table.name, values: values)
    }
    
    /// Create and updates values
    public func insert(record: RecordJSON) -> Record? {
        return insert(in: record.tableName, values: record.json.dictionaryObject ?? [:])
    }

    /// Get records that match the predicate.
    public func get(in table: Table, matching predicate: NSPredicate) throws -> [Record]? {
        return try get(in: table.name, matching: predicate)
    }

    /// Update the records that match the predicate with the given `values`
    public func update(in table: Table, matching predicate: NSPredicate, values: [String : Any]) throws -> Bool {
        return try update(in:  table.name, matching: predicate, values: values)
    }
    
    /// Check if there is records that match the predicate.
    public func has(in table: Table, matching predicate: NSPredicate) throws -> Bool {
        return try has(in: table.name, matching: predicate)
    }
 
    /// Delete records, which match the predicate.
    public func delete(in table: Table, matching predicate: NSPredicate? = nil) throws -> Bool {
        return try delete(in: table.name, matching: predicate ?? NSPredicate.true) // xxx remove predicate when updated
    }

}
