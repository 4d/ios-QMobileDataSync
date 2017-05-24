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

// MARK: Sync
extension DataSync {

    struct Process {
        
        public typealias ProcessError = AnyError

        public typealias TableStatus = (Table, TableStampStorage.Stamp)
        public typealias TableResult = Result<TableStatus, ProcessError>
        public typealias TablePageResult = Result<Page, ProcessError>
        public typealias CompletionHandler = (Result<TableStampStorage.Stamp, ProcessError>) -> Void

        // list of table to sync
        let tablesByName: [String: Table]
        // stamp
        let startStamp: TableStampStorage.Stamp

        let cancellable: Cancellable?
        let completionHandler: CompletionHandler

        var tablesResults: [String: TableResult] = [:]

        init(tables: [String: Table], startStamp: TableStampStorage.Stamp, cancellable: Cancellable?, completionHandler: @escaping CompletionHandler) {
            self.tablesByName = tables
            self.startStamp = startStamp
            self.cancellable = cancellable
            self.completionHandler = completionHandler
        }
    }

}

extension DataSync.Process {

    // A table has been synchornized with a specific result
    mutating func completed(for table: Table, with tableResult: TablePageResult) {
        tablesResults[table.name] = tableResult.map { return (table, $0.globalStamp) }

        if case .failure = tableResult {
            // XXX if error fatal like network not reachable, stop the other task?
            // if yes check that after cancelling completionHandler must be called also
            // Do a retry immediately? or wait all table process end?_
            // tablesResults[table.name] = nil
        }

        checkCompleted()
    }

    var isCompleted: Bool {
        // there is all status filled, so all task end
        // /!\ be careful to remove status when relaunching a task on specific table
        return tablesResults.count == tablesByName.count
    }

    mutating func checkCompleted() {
        // TODO synchronize method to not have false result
        // maybe Future?Promize or a Lock
        if isCompleted {
            let result: Result<[TableStatus], ProcessError> = tablesResults.values.sequence()
            do {
                let tableStatus = try result.dematerialize()

                // If all tableStatus are complete with same globalStamp
                let stamps = tableStatus.map { $0.1 }
                let maxStamp = stamps.max() ?? startStamp
                let sameStamp = stamps.min() == maxStamp
                if sameStamp {
                    self.completionHandler(.success(maxStamp))
                } else {
                    // TODO ELSE some table stamps are outdated
                    // ask a loadRecords starting at the specified stamp
                    // maybe with also a maximum stamp, the wanted global one (or let the process start to sync )
                    for (table, stamp) in tableStatus where stamp < maxStamp {
                        tablesResults[table.name] = nil
                    }
                }
            }
            catch {
                // TODO according to errors, remove all adding objects, or return an error for incomplete sync
                // String(data: (((error as! AnyError).error as! APIError).error as! MoyaError).response!.data, encoding: .utf8)
                self.completionHandler(.failureMappable(error))
            }

        }
    }
}

// MARK: cancellable
extension DataSync.Process: Cancellable {
    public func cancel() { cancellable?.cancel() }
    public var isCancelled: Bool { return cancellable?.isCancelled ?? true }
}
