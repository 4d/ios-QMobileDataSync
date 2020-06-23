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

import Prephirences

// MARK: Sync
extension DataSync {

    class Process: LockableBySync, Equatable {
        public typealias ProcessError = APIError

        public typealias TableStatus = (Table, TableStampStorage.Stamp)
        public typealias TableResult = Result<TableStatus, ProcessError>
        public typealias TablePageResult = Result<PageInfo, ProcessError>
        public typealias CompletionHandler = (Result<TableStampStorage.Stamp, ProcessError>, @escaping () -> Void) -> Void

        // list of table to sync
        let tables: [Table]
        var operation: DataSync.Operation
        let uuid = UUID().uuidString
        // stamp
        var startStamp: TableStampStorage.Stamp

        let cancellable: Cancellable?
        let completionHandler: CompletionHandler

        var tablesResults: [String: TableResult] = [:]

        init(tables: [Table], startStamp: TableStampStorage.Stamp, operation: DataSync.Operation, cancellable: Cancellable?, completionHandler: @escaping CompletionHandler) {
            self.tables = tables
            self.startStamp = startStamp
            self.operation = operation
            self.cancellable = cancellable
            self.completionHandler = completionHandler
        }

        static func == (lhs: DataSync.Process, rhs: DataSync.Process) -> Bool {
            return lhs.uuid == rhs.uuid
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
                self.complete(with: .success(maxStamp))
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
            self.complete(with: .mapOtherError(error))
            return nil
        }
    }

    fileprivate func complete(with result: Result<TableStampStorage.Stamp, ProcessError>) {
        self.completionHandler(result) {
            self.finalCompletion()
        }
    }

    func completedAndCheck(for table: Table, with tableResult: TablePageResult) -> [TableStatus]? {
        _ = self.lock()
        defer { _ = self.unlock() }
        self.completed(for: table, with: tableResult)
        return self.checkCompleted()
    }

    fileprivate func finalCompletion() {
        if DataSync.instance.process == self {
            DataSync.instance.process = nil
        }
    }
}

// MARK: cancellable
extension DataSync.Process: Cancellable {
    public func cancel() { cancellable?.cancel() }
    public var isCancelled: Bool { return cancellable?.isCancelled ?? true }
}

extension Result where Error: ErrorConvertible {
    public static func mapOtherError(_ error: Swift.Error) -> Result<Value, Error> {
        if let std = error as? Error {
            return .failure(std)
        }
        return .failure(Error.error(from: error))
    }
}
