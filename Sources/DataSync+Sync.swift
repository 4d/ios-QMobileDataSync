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
    public typealias SyncCompletionHandler = (SyncResult) -> Void
    public typealias SyncFuture = Future<Void, DataSyncError>

    public func sync(dataStoreContextType: DataStoreContextType = .background, queue: DispatchQueue? = nil, _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable? {

        cancel()
        // TOTEST maybe wait process cancel...

        // Manage delegate completion event
        let completionHandler = wrap(completionHandler: completionHandler)

        let cancellable = CancellableComposite() // return value, a cancellable

        let future = initFuture(dataStoreContextType: dataStoreContextType, queue: queue)
        future.onFailure { error in
            completionHandler(.failure(error))
        }
        future.onSuccess {
            logger.info("Start data synchronisation")
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
            Notification(name: .dataSyncBegin, object: self.tables).post()
            let stop = self.delegate?.willDataSyncBegin(tables: self.tables) ?? false
            if stop {
                logger.info("Data synchronisation stop requested before starting the process")
                completionHandler(.failure(.delegateRequestStop))
                return
            }

            // perform a data store task in background
            let perform = self.dataStore.perform(dataStoreContextType) { [weak self] context, save in
                guard let this = self else {
                    // memory issue, must retain the dataSync object somewhere
                    completionHandler(.failure(.retain))
                    return
                }
                let queue: DispatchQueue = queue ?? context.queue

                // From remote
                let processCompletion = this.processCompletionCallBack(completionHandler, context: context, save: save)
                let process = Process(tables: tablesByName, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                // assert(this.process == nil)
                this.process = process

                // For each table get data from last global stamp
                let configureRequest = this.configureRequest(stamp: startStamp)
                for table in this.tables {
                    logger.debug("Start data synchronisation for table \(table.name)")
                    let requestCancellable = this.syncTable(table, queue: queue, configureRequest: configureRequest, context: context, save: save)
                    cancellable.append(requestCancellable)
                }
            }
            if !perform {
                logger.warning("Cannot get data: context cannot be created on data store")
                completionHandler(.failure(.dataStoreNotReady))
            }
        }
        return cancellable
    }

    func processCompletionCallBack(_ completionHandler: @escaping SyncCompletionHandler, context: DataStoreContext, save: @escaping VoidClosure) -> Process.CompletionHandler {
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
            request.limit(Preferences.requestPageLimit)
            // stamp filter
            let filter = "\(kStampFilter)=\(stamp)"
            request.filter(filter)
        }
    }

}

/*
extension MoyaError: CustomDebugStringConvertible {
    
    var debugDescription: String {
        
        return self.localizedDescription
        
    }
 
    
}*/
