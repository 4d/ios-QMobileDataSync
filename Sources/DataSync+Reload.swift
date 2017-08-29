//
//  DataStore+Reload.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 28/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileDataStore
import QMobileAPI
import FileKit
import Moya

extension DataSync {

    func reload(dataStoreContextType: DataStoreContextType = .background, queue: DispatchQueue? = nil, _ completionHandler: @escaping SyncCompletionHandler) -> Cancellable {
        if !isCancelled {
            cancel()
            // XXX maybe wait...
        }

        // Manage delegate completion event
        let completionHandler: SyncCompletionHandler = wrap(completionHandler: completionHandler)

        let cancellable = CancellableComposite() // return value, a cancellable

        initFuture(dataStoreContextType: dataStoreContextType, queue: queue)
            .onFailure { error in
                completionHandler(.failure(error))
            }
            .onSuccess {
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

                    // From remote
                    let processCompletion = this.processCompletionCallBack(completionHandler, context: context, save: save)
                    let process = Process(tables: tablesByName, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                    // assert(this.process == nil)
                    this.process = process

                    let tableQueue: DispatchQueue?
                    if let queue = queue {
                        tableQueue = queue
                    } else {
                        switch context.type {
                        case .background: tableQueue = .background
                        case .foreground: tableQueue = .main
                        }
                    }

                    if let currentDispatch = OperationQueue.current?.underlyingQueue {
                        print(currentDispatch)
                    }

                    // For each table get data from last global stamp
                    //let configureRequest = this.configureRequest(stamp: startStamp)
                    for table in this.tables {
                        logger.debug("Start data synchronisation for table \(table.name)")
                        let requestCancellable = this.reloadTableR(table, queue: tableQueue, context: context, save: save)
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

    func reloadTableR(_ table: Table, queue: DispatchQueue? = nil, context: DataStoreContext, save: @escaping VoidClosure) -> Cancellable {
       let tableName = table.name
        logger.debug("Load records for \(tableName)")
        Notification(name: .dataSyncForTableBegin, object: table).post()
        self.delegate?.willDataSyncBegin(for: table)

        var target = rest.rest.records(from: table.name, attributes: [])
        target.limit(Preferences.requestLimit)

        let progress: APIManager.ProgressHandler = { progress in

        }

        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let reponse):

                logger.debug("Receive record for table '\(tableName)'")

                print("response \(reponse)")
                let pageInfo = PageInfo.dummy
                self.delegate?.didDataSyncEnd(for: table, page: pageInfo)
                Notification(name: .dataSyncForTableSuccess, object: (table, pageInfo)).post()

                if var process = self.process {
                    // #FIXME dead lock here????
                    logger.verbose("will lock process")
                    objc_sync_enter(process)
                    logger.verbose("did lock process")
                    defer {
                        logger.verbose("will unlock process")
                        objc_sync_exit(process)
                        logger.verbose("did unlock process")
                    }

                    self.process?.completed(for: table, with: .success(pageInfo))

                    if let tableStatus = self.process?.checkCompleted() {

                    }
                }

            case .failure(let error):
                var errorMessage = "\(error)"
                if let requestCase = APIError(underlying: error).requestCase {
                    errorMessage = "\(requestCase) (\(error.localizedDescription))"
                }

                logger.warning("Failed to get records for table \(tableName): \(errorMessage)")

                Notification(name: .dataSyncForTableFailed, object: (table, error)).post()
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

        return rest.request(target, queue: queue, progress: progress, completion: completion)

    }
}

extension PageInfo {

    public static let dummy = PageInfo(globalStamp: 0, sent: 10000, first: 0, count: 10000)
}
