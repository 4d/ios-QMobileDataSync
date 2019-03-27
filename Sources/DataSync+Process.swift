//
//  DataSync+Process.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import QMobileAPI
import Moya
import Result
import Prephirences

// MARK: Sync
extension DataSync {

    class Process: LockableBySync {

        public typealias ProcessError = APIError

        public typealias TableStatus = (Table, TableStampStorage.Stamp)
        public typealias TableResult = Result<TableStatus, ProcessError>
        public typealias TablePageResult = Result<PageInfo, ProcessError>
        public typealias CompletionHandler = (Result<TableStampStorage.Stamp, ProcessError>) -> Void

        // list of table to sync
        let tables: [Table]
        // stamp
        let startStamp: TableStampStorage.Stamp

        let cancellable: Cancellable?
        let completionHandler: CompletionHandler

        var tablesResults: [String: TableResult] = [:]

        init(tables: [Table], startStamp: TableStampStorage.Stamp, cancellable: Cancellable?, completionHandler: @escaping CompletionHandler) {
            self.tables = tables
            self.startStamp = startStamp
            self.cancellable = cancellable
            self.completionHandler = completionHandler
        }

    }

}

extension DataSync.Process {

    /// A table has been synchornized with a specific result
    func completed(for table: Table, with tableResult: TablePageResult) {
        tablesResults[table.name] = tableResult.map { return (table, $0.globalStamp) }

        if case .failure = tableResult {
            // XXX if error fatal like network not reachable, stop the other task?
            // if yes check that after cancelling completionHandler must be called also
            // Do a retry immediately? or wait all table process end?_
            // tablesResults[table.name] = nil
        }
    }

    /// All table has been sync?
    var isCompleted: Bool {
        // there is all status filled, so all task end
        // /!\ be careful to remove status when relaunching a task on specific table
        return tablesResults.count == tables.count
    }

    /// Check if completed and give status if true, othewise return nil.
    func checkCompleted() -> [TableStatus]? {
        // maybe Future?Promize or a Lock
        logger.debug("There is \(tablesResults.count)/\(tables.count) tables sync")

        guard isCompleted else {
            return nil
        }

        let result: Result<[TableStatus], ProcessError> = tablesResults.values.sequence()
        do {
            let tableStatus = try result.get()

            // If all tableStatus are complete with same globalStamp
            var stamps = tableStatus.map { $0.1 }
            stamps.removeAll(where: { $0 == PageInfo.ignoredGlobalStamp })
            let maxStamp = stamps.max() ?? startStamp
            let sameStamp = stamps.min() == maxStamp
            if sameStamp || stamps.isEmpty {
                self.completionHandler(.success(maxStamp))
                return nil
            } else {
                // else some table stamps are outdated
                for (table, stamp) in tableStatus where stamp < maxStamp {
                    tablesResults[table.name] = nil
                }
                // ask to sync table starting at the current table stamp
                return tableStatus.filter { $0.1 < maxStamp}
            }
        } catch {
            // TODO according to errors, remove all added objects, or return an error for incomplete sync
            // String(data: (((error as! AnyError).error as! APIError).error as! MoyaError).response!.data, encoding: .utf8)
            self.completionHandler(.mapOtherError(error))
            return nil
        }
    }

    func completedAndCheck(for table: Table, with tableResult: TablePageResult) -> [TableStatus]? {
        _ = self.lock()
        defer { _ = self.unlock() }
        self.completed(for: table, with: tableResult)
        return self.checkCompleted()
    }
}

// MARK: cancellable
extension DataSync.Process: Cancellable {
    public func cancel() { cancellable?.cancel() }
    public var isCancelled: Bool { return cancellable?.isCancelled ?? true }
}
