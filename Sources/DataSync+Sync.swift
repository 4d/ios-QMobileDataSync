//
//  DataSync+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 15/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Result
import Prephirences
import BrightFutures
import Moya

import QMobileDataStore
import QMobileAPI

let kStampFilter = "__stamp"

// MARK: Sync
extension DataSync {

    public typealias SyncResult = Result<Void, DataSyncError>
    public typealias SyncCompletionHander = (SyncResult) -> Void
    public typealias SyncFuture = Future<Void, DataSyncError>
    public func sync(_ completionHandler: @escaping SyncCompletionHander) -> Cancellable? {

        if !isCancelled {
            cancel()
            // XXX maybe wait...
        }

        let cancellable = CancellableComposite() // return value, a cancellable

        initFuture()
            .onFailure { error in
                completionHandler(.failure(error))
            }
            .onSuccess {
                // Check if metadata could be read
                guard let metadata = self.dataStore.metadata else {
                    logger.warning("Could not read metadata from datastore")
                    completionHandler(.failure(.dataStoreNotReady))
                    return
                }

                // Get data from this global stamp
                let startStamp = metadata.stampStorage.globalStamp
                let tablesByName = self.tablesByName

                // Ask delegate if there is any reason to stop process
                let stop = self.delegate?.willDataSyncBegin(tables: self.tables) ?? false
                if stop {
                    completionHandler(.failure(.delegateRequestStop))
                    return
                }

                // perform a data store task in background
                let perform = self.dataStore.perform(.background) { [weak self] context, save in
                    guard let this = self else {
                        // memory issue, must retain the dataSync object somewhere
                        completionHandler(.failure(.retain))
                        return
                    }

                    // from file (maybe move this code elsewhere) TODO move code to load from file elsewhere
                    if Preferences.firstSync {
                        if Preferences.dataFromFile {
                            self?.loadRecordsFromFile(context: context, save: save)
                        }
                        Preferences.firstSync = false
                    }

                    // From remote
                    let processCompletion = this.processCompletionCallBack(completionHandler, context: context, save: save)
                    let process = Process(tables: tablesByName, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                   // assert(this.process == nil)
                    this.process = process

                    // For each table get data from last global stamp
                    let configureRequest = this.configureRequest(stamp: startStamp)
                    let currentDispatch = OperationQueue.current?.underlyingQueue
                    for table in this.tables {
                        let requestCancellable = this.syncTable(table, queue: currentDispatch, configureRequest: configureRequest, context: context, save: save)
                        cancellable.append(requestCancellable)
                    }
                }
                // return no task if dataStore not ready
                if !perform {
                    logger.warning("Cannot get data: context cannot be created on data store")
                    completionHandler(.failure(.dataStoreNotReady))
                    return

                }
        }
        return cancellable
    }

    /// check data store loaded, and tables structures loaded
    private func initFuture(queue: DispatchQueue? = nil) -> SyncFuture {
        var sequence: [SyncFuture] = []

        // Load data store if necessary
        /*dataStore.drop {
         dataStore.load {
         
         }*/

        if Prephirences.sharedInstance.bool(forKey: "dataSync.dataStoreDrop") {

            let dsLoad: SyncFuture = dataStore.drop().flatMap {
                return self.dataStore.load()
                }.mapError { dataStoreError in
                    logger.warning("Could not drop or load data store \(dataStoreError)")
                    return .dataStoreError(dataStoreError)
            }
            sequence.append(dsLoad)

        } else {
            let dsLoad: SyncFuture = dataStore.load().mapError { dataStoreError in
                logger.warning("Could not load data store \(dataStoreError)")
                return .dataStoreError(dataStoreError)
            }
            sequence.append(dsLoad)
        }

        // Load table if needed
        let loadTable: Future<[Table], DataSyncError> = self.loadTable(queue: queue).mapError { apiError in
            logger.warning("Could not load table \(apiError)")
            return .apiError(apiError)
        }
        /// check if there is table
        let checkTable: SyncFuture = loadTable.flatMap { (tables: [Table]) -> SyncResult in
            if self.tables.isEmpty {
                return .failure(.noTables)
            }
            return .success()
        }
        sequence.append(checkTable)

        if Prephirences.sharedInstance.bool(forKey: "dataSync.deleteRecords") {
            // if must removes all the data by tables
            let removeTableRecords: SyncFuture = loadTable.flatMap { (tables: [Table]) -> SyncFuture in

                return self.dataStore.perform(.background).flatMap { (dataStoreContext: DataStoreContext, save: () throws -> Void) -> Result<Void, DataStoreError> in
                    // delete all table data
                    do {
                        for table in self.tables {
                            let bool = try dataStoreContext.delete(in: table)
                            logger.debug("Data of table \(table.name) deleted: \(bool)")
                        }
                        try save()
                        return .success()
                    } catch let dataStoreError as DataStoreError {
                        return .failure(dataStoreError)
                    } catch {
                        return .failure(DataStoreError(error))
                    }

                    }.mapError { dataStoreError in
                        logger.warning("Could not delete records from data store \(dataStoreError)")
                        return DataSyncError.dataStoreError(dataStoreError)
                }
            }
            sequence.append(removeTableRecords)
        }

        return sequence.sequence().asVoid()
    }

    private func processCompletionCallBack(_ completionHandler: @escaping SyncCompletionHander, context: DataStoreContext, save: @escaping DataStore.SaveClosure) -> Process.CompletionHandler {
        return { result in
            switch result {
            case .success(let stamp):
                // store new stamp
                var metadata = self.dataStore.metadata
                metadata?.globalStamp = stamp
                metadata?.lastSync = Date()

                // save data store
                self.trySave(save)

                // call success
                completionHandler(.success())
            case .failure(let error):
                if case .onCompletion = self.saveMode {
                    context.rollback()
                }
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

    func configureRequest(stamp: TableStampStorage.Stamp) -> ((RecordsRequest) -> Void) {
        return { request in
            request.limit(Preferences.requestLimit)
            // stamp filter
            let filter = "\(kStampFilter)=\(stamp)"
            request.filter(filter)
        }
    }

    func syncTable(_ table: Table, queue: DispatchQueue? = nil, configureRequest: @escaping ((RecordsRequest) -> Void), context: DataStoreContext, save: @escaping DataStore.SaveClosure) -> Cancellable {
        let tableName = table.name
        logger.debug("Load records for \(tableName)")
        self.delegate?.willDataSyncBegin(for: table)

        let initializer = self.recordInitializer(table: table, context: context)
        var cancellable = CancellableComposite()
        let cancellableRecords = self.rest.loadRecords(table: table, recursive: true, configure: configureRequest, initializer: initializer, queue: queue) { result in
            switch result {
            case .success(let (records, page)):
                logger.debug("Receive page '\(page)' for table '\(tableName)'")
                #if DEBUG
                    let stamps = records.map { $0.__stamp }
                    if let max = stamps.max(), max > page.globalStamp {
                        logger.warning("GlobalStamp(\(page.globalStamp)) is not updated. Receive a record with stamp \(max)'")
                    }
                #endif

                // TODO check/save global stamp and current one
                // TODO If a table have more recent stamp resync this table

                if page.isLast {
                    logger.info("Last page loaded for table \(tableName)")

                    self.delegate?.didDataSyncEnd(for: table, page: page)
                    if case .byTable = self.saveMode {
                        self.trySave(save)
                        // If save could not manage error
                    }
                }
                if case .eachPage = self.saveMode {
                    self.trySave(save)
                }
                if page.isLast {

                    if var process = self.process {
                        objc_sync_enter(process)
                        defer {
                            objc_sync_exit(process)
                        }

                        self.process?.completed(for: table, with: .success(page))

                        if let tableStatus = self.process?.checkCompleted() {
                            // There is some table to relaunch sync
                            for (table, stamp) in tableStatus {
                                let configureRequest = self.configureRequest(stamp: stamp)
                                let c = self.syncTable(table, configureRequest: configureRequest, context: context, save: save)
                                cancellable.append(c)
                            }
                        }
                    }
                }
            case .failure(let error):
                var errorMessage = "\(error)"
                if let requestCase = error.requestCase {
                    errorMessage = "\(requestCase) (\(error.localizedDescription))"
                }

                logger.warning("Failed to get records for table \(tableName): \(errorMessage)")

                self.delegate?.didDataSyncFailed(for: table, error: error)

                if var process = self.process {
                    objc_sync_enter(process)
                    defer {
                        objc_sync_exit(process)
                    }

                    self.process?.completed(for: table, with: .failureMappable(error))

                    _ = self.process?.checkCompleted()
                }
            }
        }
        cancellable.append(cancellableRecords)

        return cancellable
    }

}

/*
extension MoyaError: CustomDebugStringConvertible {
    
    var debugDescription: String {
        
        return self.localizedDescription
        
    }
 
    
}*/

public extension DataStore {
    typealias SaveClosure  = () throws -> Swift.Void
}
