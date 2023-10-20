//
//  DataSync+Deletable.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 06/02/2020.
//  Copyright © 2020 Eric Marchand. All rights reserved.
//

import Foundation
import Combine

import Prephirences

import Moya
import FileKit

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
typealias DeletedRecordFuture = AnyPublisher<[DeletableRecord], APIError>
extension DeletedRecord: DeletableRecord {
    func predicate(table: Table) -> NSPredicate? {
        return table.predicate(forDeletedRecord: self)
    }
}
extension QMobileDataStore.Record: DeletableRecord {
    func predicate(table: Table) -> NSPredicate? {
        return table.predicate(for: self)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension DataSync {

    // MARK: process completion callback

    /// Delete records defined by info provided by `DeletableRecord` objects.
    func deleteRecords(_ deletedRecords: [DeletableRecord], in context: DataStoreContext) {
        if Prephirences.DataStore.bachDelete {
            let deletedRecordsByTable: [String: [DeletableRecord]] = Dictionary(grouping: deletedRecords, by: { $0.tableName })

            for (tableName, deletedRecordsOfTable) in deletedRecordsByTable {
                guard let table = table(for: tableName), let tableInfo = self.tablesInfoByTable[table] else {
                    logger.verbose("Unknown table \(tableName). Not managed table.")
                    continue
                }

                let predicates = deletedRecordsOfTable.compactMap { $0.predicate(table: table) }
                if predicates.isEmpty {
                    logger.warning("Failed to delete \(deletedRecordsOfTable). Cannot get primary key and predicate to find it.")
                    continue
                }
                for chunk in predicates.chunked(into: 100) {
                    do {
                        let predicate = NSCompoundPredicate(type: .or, subpredicates: Array(chunk))
                        let result = try context.delete(in: tableInfo.name, matching: predicate)
                        if result != chunk.count {
                            if logger.isEnabledFor(level: .verbose) {
                                logger.verbose("Record defined by \(chunk) has been deleted")
                            }
                        } else {
                            logger.debug("Failed to delete some records: \(result) on \(chunk.count). Maybe already deleted.")
                        }
                    } catch {
                        logger.warning("Failed to delete \(chunk). Maybe already deleted \(error)")
                    }
                }
            }
            return
        }

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
    func pendingRecords(for context: DataStoreContext) -> DeletedRecordFuture {
        return Just(context.pendingRecords).setFailureType(to: APIError.self).eraseToAnyPublisher()
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
                request.limit(Prephirences.DataSync.Request.deleteLimit)
            }
            let deletedRecordPageFuture: DeletedRecordFuture = self.apiManager.deletedRecordPage(configure: configure, callbackQueue: callbackQueue, progress: progress).map { page in
                return page.records.compactMap { $0.deletedRecord }
            }.eraseToAnyPublisher()
            futures.append(deletedRecordPageFuture)
        }

        let pendingRecordFuture = self.pendingRecords(for: context)

        futures.append(pendingRecordFuture)

        if Prephirences.DataSync.deletedByFilter {
            // then for all table with filters. in fact some records could now be out of filter scope.
            let configure: APIManager.ConfigureRecordsRequest? = { request in
                request.filter("\(kGlobalStamp) >= \(startStamp) AND \(kGlobalStamp) <= \(endStamp)")  // synchronized interval
                request.limit(Prephirences.DataSync.Request.deleteLimit)
            }
            futures += deletedRecordsDueToFilter(in: context, configure: configure)
        }
        // Merge and flattenize all task result
        return futures.sequence().result { (list: [[DeletableRecord]]) -> Result<[DeletableRecord], APIError> in
            return .success(list.flatMap { $0 })
        }
    }

    /// Synchronize removed record due to filter only
    func deletedRecordsDueToFilter(in context: DataStoreContext, configure: APIManager.ConfigureRecordsRequest? = nil) -> [DeletedRecordFuture] {
        // work only on tables with filter
        let tablesWithFilter = tablesInfoByTable.filter { $1.filter != nil }

        // Find the updated or created records. This records must not be deleted, because we get it with filter
        let updatedRecords: [QMobileDataStore.Record] = context.insertedRecords + context.updatedRecords
        let updatedRecordsByTable: [String: [QMobileDataStore.Record]] = updatedRecords.dictionaryBy { $0.tableName }

        var futures: [DeletedRecordFuture] = []
        for (table, tableInfo) in tablesWithFilter {
            // Get table information
            guard let primaryKey = tableInfo.primaryKeyFieldInfo?.originalName else {
                continue
            }
            let tableName = table.name
            let updatedRecords: [QMobileDataStore.Record] = updatedRecordsByTable[tableName] ?? [] // maybe no one visible for this table
            let updatedRecordPrimaryKeys = updatedRecords.compactMap { $0.primaryKeyValue }

            // Make the request to get records
            let future = APIManager.instance.recordPage(tableName: tableName, attributes: [primaryKey: true], configure: configure).map { (page: Page) -> [DeletableRecord] in
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
            }.eraseToAnyPublisher()
            futures.append(future)
        }
        return futures
    }
}
