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

import Result
import Moya // Cancellable

let logger = Logger.forClass(DataSync.self) // XXX check if configuration not already done...
public class DataSync {

    /// Object to make remote request
    public let rest: APIManager
    /// Mobile data store
    public let dataStore: DataStore

    public init(rest: APIManager = APIManager(url: Preferences.remoteServerURL), dataStore: DataStore = QMobileDataStore.dataStore) {
        self.rest = rest
        self.dataStore = dataStore
    }

    /// Bundle for files (JSON tables and data)
    public var bundle: Bundle = .main

    /// List of loaded tables indexed by name
    public var tablesByName: [String: Table] = [:]

    // shorcut to get only tables
    var tables: [Table] {
        return Array(self.tablesByName.values)
    }

    public weak var delegate: DataSyncDelegate?

    /// If true save each records page received
    /// otherwise save after a complete table loading
    public var saveMode: SaveMode = .onCompletion
    
    public enum SaveMode {
        case eachPage
        case byTable
        case onCompletion
    }
}

public protocol DataSyncDelegate: NSObjectProtocol {

    // Notify data sync begin
    // return a bool to stop sync if needed
    func willDataSyncBegin(tables: [Table]) -> Bool

    func willDataSyncBegin(for table: Table)

    func dataSync(for table: Table, page: Page)

    func didDataSyncEnd(for table: Table, page: Page)
    func didDataSyncFailed(for table: Table, error: Swift.Error)

    func didDataSyncEnd(tables: [Table])

    func error(error: Swift.Error)
}

public enum DataSyncError: Swift.Error {
    /// memory issue, data sync object is no more attached
    case retain
    /// data store is not ready
    case dataStoreNotReady
    /// Loading tables failed, check your tables structures
    case noTables
    /// Sync delegate request stop of process before starting it
    case delegateRequestStop
}

// MARK: Sync
extension DataSync {

    /*
     public func cancel() {
     // TODO cancel all requests, or return a cancellable object in sync function
    }*/
    
    struct Process {
        
        enum TableStatus { // Replace by a Result?
            case failure(Swift.Error)
            case success(TableStampStorage.Stamp)
        }
        
        // list of table to sync
        let tablesByName: [String: Table]
        // metadata object where to store stamp
        var stampStorage: TableStampStorage
        let cancellable: Cancellable?
        let completionHandler: ((Bool) -> Void)?
        

        var tableStatus: [String: TableStatus] = [:]
        var tableStamp: [String: TableStampStorage.Stamp] = [:]
        let globalStamp: TableStampStorage.Stamp

        init(tablesByName: [String: Table], stampStorage: TableStampStorage, cancellable: Cancellable?, completionHandler: ((Bool) -> Void)? = nil ) {
            self.tablesByName = tablesByName
            self.stampStorage = stampStorage
            self.cancellable = cancellable
            self.completionHandler = completionHandler
            
            // Dump stamps before processing
            self.globalStamp = stampStorage.globalStamp
            for (name, table) in tablesByName {
                self.tableStamp[name] = self.stampStorage.stamp(for: table)
            }
        }
        
        // XXX maybe replace page and error with a result
        mutating func completed(for table: Table, with result: Result<Page, AnyError>) {
           
            // remove from table to process ? or just edit a satus
            // tablesByName.removeValue(forKey: table.name)
            // TODO store stamp by table

            switch result {
            case .success(let page):
                assert(page.isLast)
                // let oldStamp = tableStamp[table.name]
                
                let newStamp =  page.globalStamp // take new stamp from last page
                
                // TODO store new stamp, only if all process end?, process will start with globalStamp, so not necessary
                // stampStorage.set(stamp: newStamp, for: table)
                
                tableStatus[table.name] = .success(newStamp)
            case .failure(let error):
                
                
                // TODO if error, stop the other task? if yes, check cancel do not prevent to call completionHandler
                // or call it here with error result
                // cancellable?.cancel()
                
                // or on some error do a retry

                tableStatus[table.name] = .failure(error)
            }

            // TODO check stamp consistency
            // If not request a new sync
            
            
            let allTableSync = tableStatus.count == tablesByName.count
            if allTableSync {
                
                // TODO if all tableStatus are complete(with same globalStamp)
                // TODO according to errors, remove all adding objects, or return an error for incomplete sync
                let rollback = false
                //let result: Result<Void, DataSyncError> = .success()
                self.completionHandler?(rollback)
                
                // metadata.globalStamp = newStamp // TODO the good last globalStamp
                
                // TODO ELSE some table stamps are outdated
                // ask a loadRecords starting at the specified stamp
                // maybe with also a maximum stamp, the wanted global one (or let the process start to sync )
            }
        }
    }

    public typealias SyncCompletionHander = (Result<Void, DataSyncError>) -> Void
    public func sync(_ completionHandler: @escaping SyncCompletionHander) -> Cancellable? {

        // TODO If there is already a sync stop it, maybe add a bool force and only if force=true, or do nothing

        // TODO get last stamp from dataStore metadata

        guard let metadata = dataStore.metadata else {
            logger.warning("Could not read metadata from datastore")
            completionHandler(.failure(.dataStoreNotReady))
            return nil
        }

        let stop = self.delegate?.willDataSyncBegin(tables: self.tables) ?? false
        if stop {
            completionHandler(.failure(.delegateRequestStop))
            return nil
        }

        if self.tablesByName.isEmpty { // no request to do if no table
            completionHandler(.failure(.noTables))
            return nil
        }

        let tablesByName = self.tablesByName
        var cancellable = CancellableComposite() // return value, a cancellable

        // perform a data store task in background
        let perform = dataStore.perform(.background) { [weak self] context, save in
            guard let this = self else {
                completionHandler(.failure(.retain))
                return
            }

            // from file (maybe move this code elsewhere)
            if Preferences.firstSync {
                if Preferences.dataFromFile {
                    self?.loadRecordsFromFile(context: context, save: save)
                }
                Preferences.firstSync = false
            }

            // From remote
            var process = Process(tablesByName: tablesByName, stampStorage: metadata.stampStorage, cancellable: cancellable) { rollback in
                if case .onCompletion = this.saveMode {
                    if rollback {
                        context.rollback()
                    }
                    else {
                        this.trySave(save)
                    }
                } else {
                    
                }
                // TODO return result success or error
                // completionHandler(Result<Void, DataSyncError>)
            }

            let configureRequest: ((RecordsRequest) -> Void) = { request in
                request.limit(Preferences.requestLimit)
                // TODO stamp filter
                let filter = "__stamp=\(process.globalStamp)"
                request.filter(filter)
            }
            // For each table get data from last global stamp
            for (tableName, table) in tablesByName {
                logger.debug("Load records for \(tableName)")
                this.delegate?.willDataSyncBegin(for: table)

                let initializer = this.recordInitializer(table: table, context: context)
                let requestCancellable = this.rest.loadRecords(table: table, configure: configureRequest, initializer: initializer) { result in
                    switch result {
                    case .success(let (_, page)):
                        logger.debug("Receive page '\(page)' for table '\(tableName)'")
                        
                        // TODO check/save global stamp and current one
                        // TODO If a table have more recent stamp resync this table

                        if page.isLast {
                            logger.info("Last page loaded for table \(tableName)")
                            
                            this.delegate?.didDataSyncEnd(for: table, page: page)
                            if case .byTable = this.saveMode {
                                this.trySave(save)
                                // If save could not manage error
                            }
                        }
                        if case .eachPage = this.saveMode {
                            this.trySave(save)
                        }
                        if page.isLast {
                            process.completed(for: table, with: .success(page))
                        }
                    case .failure(let error):
                        logger.warning("Failed to get records for table \(tableName): \(error)")
                        this.delegate?.didDataSyncFailed(for: table, error: error)
                        process.completed(for: table, with: .failure(AnyError(error)))
                    }
                }
                cancellable.list.append(requestCancellable)
            }
        }
        // return no task if dataStore not ready
        if !perform {
            logger.warning("Cannot get data: context cannot be created on data store")
            completionHandler(.failure(.dataStoreNotReady))
            return nil
        }
        return cancellable
    }
    
}
