//
//  DataSync+Deletable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 06/02/2020.
//  Copyright © 2020 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences

import Moya
import FileKit
import BrightFutures

import QMobileAPI
import QMobileDataStore

// MARK: - delete

/// Define a record to delete.
protocol DeletableRecord {
    /// Table name.
    var tableName: String { get }
    /// Return the predicate to remove records.
    func predicate(table: Table) -> NSPredicate?
}
typealias DeletedRecordFuture = Future<[DeletableRecord], APIError>
extension DeletedRecord: DeletableRecord {
    func predicate(table: Table) -> NSPredicate? {
        return table.predicate(forDeletedRecord: self)
    }
}
extension Record: DeletableRecord {
    func predicate(table: Table) -> NSPredicate? {
        return table.predicate(for: self)
    }
}

extension DataSync {

    // MARK: process completion callback

    /// Delete records defined by info provided by `DeletableRecord` objects.
    func deleteRecords(_ deletedRecords: [DeletableRecord], in context: DataStoreContext) {
        for deletedRecord in deletedRecords {
            guard let table = table(for: deletedRecord.tableName), let tableInfo = self.tablesInfoByTable[table] else {
                logger.verbose("Unknown record \(deletedRecord). Not managed table.")
                continue
            }
            do {
                guard let predicate = deletedRecord.predicate(table: table) else {
                    logger.warning("Failed to delete \(deletedRecord). Cannot get primary key and predicate to find it.")
                    continue
                }
                let result = try context.delete(in: tableInfo.name, matching: predicate)
                if result > 0 {
                    logger.verbose("Record defined by \(deletedRecord) has been deleted")
                } else {
                    logger.debug("Failed to delete \(deletedRecord). Maybe already deleted.")
                }
            } catch {
                logger.warning("Failed to delete \(deletedRecord). Maybe already deleted \(error)")
            }
        }
    }

    /// immediatly return the records that we do not want to persist.
    func pendingRecords() -> DeletedRecordFuture {
        let promize = Promise<[DeletableRecord], APIError>()
        let pendingRecords = Array(PendingRecord.pendingRecords)
        promize.success(pendingRecords)
        PendingRecord.pendingRecords.removeAll()
        return promize.future
    }

    /// Create futures of all record to remove according to operation type.
    func syncDeletedRecods(in context: DataStoreContext,
                           operation: DataSync.Operation,
                           startStamp: TableStampStorage.Stamp,
                           endStamp: TableStampStorage.Stamp,
                           callbackQueue: DispatchQueue? = nil,
                           progress: APIManager.ProgressHandler? = nil) -> DeletedRecordFuture {

        var futures: [DeletedRecordFuture] = []

        if case .sync = operation {
            // First get drom DeleteRecord table
            let configure: APIManager.ConfigureRecordsRequest? = { request in
                request.filter("\(DeletedRecordKey.stamp) >= \(startStamp) AND \(DeletedRecordKey.stamp) <= \(endStamp)")  // synchronized interval
            }
            let deletedRecordPageFuture: DeletedRecordFuture = self.apiManager.deletedRecordPage(configure: configure, callbackQueue: callbackQueue, progress: progress).map { page in
                return page.records.compactMap { $0.deletedRecord }
            }
            futures.append(deletedRecordPageFuture)
        }

        let pendingRecordFuture = self.pendingRecords()

        futures.append(pendingRecordFuture)

        if Prephirences.DataSync.deletedByFilter {
            // then for all table with filters. in fact some records could now be out of filter scope.
            let configure: APIManager.ConfigureRecordsRequest? = { request in
                request.filter("\(kGlobalStamp) >= \(startStamp) AND \(kGlobalStamp) <= \(endStamp)")  // synchronized interval
            }
            futures += deletedRecordsDueToFilter(in: context, configure: configure)
        }
        // Merge and flattenize all task result
        return futures.sequence().flatMap { (list: [[DeletableRecord]]) -> Result<[DeletableRecord], APIError> in
            return .success(list.flatMap { $0 })
        }
    }

    /// Synchronize removed record due to filter only
    func deletedRecordsDueToFilter(in context: DataStoreContext, configure: APIManager.ConfigureRecordsRequest? = nil) -> [DeletedRecordFuture] {
        // work only on tables with filter
        let tablesWithFilter = tablesInfoByTable.filter { $1.filter != nil }

        // Find the updated or created records. This records must not be deleted, because we get it with filter
        let updatedRecords: [Record] = context.insertedRecords + context.updatedRecords
        let updatedRecordsByTable: [String: [Record]] = updatedRecords.dictionaryBy { $0.tableName }

        var futures: [DeletedRecordFuture] = []
        for (table, tableInfo) in tablesWithFilter {
            // Get table information
            guard let primaryKey = tableInfo.primaryKeyFieldInfo?.originalName else {
                continue
            }
            let tableName = table.name
            let updatedRecords: [Record] = updatedRecordsByTable[tableName] ?? [] // maybe no one visible for this table
            let updatedRecordPrimaryKeys = updatedRecords.compactMap { $0.primaryKeyValue }

            // Make the request to get records
            let future = APIManager.instance.recordPage(tableName: tableName, attributes: [primaryKey], configure: configure).map { (page: Page) -> [DeletableRecord] in
                let records = page.records
                // Filter records that must not be deleted, ie. the ones pending to be modified by synchro
                let deletedRecords: [DeletableRecord] = records.compactMap { recordJSON in
                    let json = recordJSON.json
                    let primaryKey = "\(json[primaryKey].rawValue)"
                    let hasBeenUpdated = updatedRecordPrimaryKeys.contains { updatedPrimaryKey in
                        return ("\(updatedPrimaryKey)" == primaryKey) // use string to compare, maybe could be faster if not converted
                    }
                    if hasBeenUpdated {
                        return nil // do not deleted
                    }
                    let stamp = json[kGlobalStamp].doubleValue
                    return DeletedRecord(primaryKey: "\(primaryKey)", tableNumber: nil, tableName: tableName, stamp: stamp)
                }
                return deletedRecords
            }
            futures.append(future)
        }
        return futures
    }
}
