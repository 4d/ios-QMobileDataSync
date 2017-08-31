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
            .onSuccess { [weak self] in
                guard let this = self else {
                    // memory issue, must retain the dataSync object somewhere
                    completionHandler(.failure(.retain))
                    return
                }

                logger.info("Start data reloading")

                // Ask delegate if there is any reason to stop process
                let stop = this.dataSyncBegin()
                if stop {
                    logger.info("Data reloading stop requested before starting the process")
                    completionHandler(.failure(.delegateRequestStop))
                    return
                }

                // perform a data store task in background
                //let perform = this.dataStore.perform(dataStoreContextType) { [weak self] context, save in
                /*guard let this = self else {
                 // memory issue, must retain the dataSync object somewhere
                 completionHandler(.failure(.retain))
                 return
                 }*/

                let startStamp = 0
                let tablesByName = this.tablesByName

                // From remote
                let tempPath: Path = .userTemporary

                let processCompletion = this.reloadProcessCompletionCallBack(tempPath: tempPath, completionHandler)
                let process = Process(tables: tablesByName, startStamp: startStamp, cancellable: cancellable, completionHandler: processCompletion)

                // assert(this.process == nil)
                this.process = process

                //let queue: DispatchQueue = queue ?? context.queue

                // For each table get data from last global stamp
                //let configureRequest = this.configureRequest(stamp: startStamp)
                for table in this.tables {
                    logger.debug("Start data reloading for table \(table.name)")

                    let progress: APIManager.ProgressHandler = { progress in

                    }

                    let requestCancellable = this.reloadTable(table, in: tempPath, queue: queue, progress: progress)
                    cancellable.append(requestCancellable)
                }
                /*}*/
                // return no task if dataStore not ready
               /* if !perform {
                    logger.warning("Cannot get data: context cannot be created on data store")
                    completionHandler(.failure(.dataStoreNotReady))
                    return

                }*/
        }
        return cancellable
    }

    func reloadProcessCompletionCallBack(tempPath: Path, _ completionHandler: @escaping SyncCompletionHandler) -> Process.CompletionHandler {
        return { result in
            switch result {
            case .success(let stamp):
                // store new stamp
                var metadata = self.dataStore.metadata
                metadata?.globalStamp = stamp
                metadata?.lastSync = Date()

                let files = tempPath.children().filter { $0.pathExtension == DataSync.Preferences.jsonDataExtension }

                self.clearFileCache()

                for file in files {
                    let destination: Path = self.cachePath + file.fileName
                    try? file.copyFile(to: destination) // TODO check copy cache file error
                }

                let result = self.dataStore.perform(.background) { context, save in

                    logger.info("Load table data from embedded data files")
                    do {
                        try self.loadRecordsFromFile(context: context, save: save)
                        completionHandler(.success())
                    } catch let dataStoreError as DataSyncError {
                        completionHandler(.failure(DataSyncError.error(from: dataStoreError)))
                    } catch {
                        completionHandler(.failure(DataSyncError.error(from: DataStoreError(error))))
                    }
                }
                if !result {
                    completionHandler(.failure(DataSyncError.error(from: DataStoreError(DataStoreStateError.dataStoreNotReady))))
                }

            case .failure(let error):
                if case .onCompletion = self.saveMode {
                    // context.rollback()
                }
                completionHandler(.failure(DataSyncError.apiError(error)))
            }
        }
    }

    func reloadTable(_ table: Table, in path: Path, queue: DispatchQueue? = nil, progress: APIManager.ProgressHandler? = nil) -> Cancellable {
        dataSyncBegin(for: table)

        let cancellable = CancellableComposite()
        var target = rest.rest.records(from: table.name, attributes: [])
        target.limit(Preferences.requestLimit)

        let completion: APIManager.Completion = { result in
            switch result {
            case .success(let response):

                let path: Path = path + "\(table.name).\(DataSync.Preferences.jsonDataExtension)"
                let data = response.data

                if path.exists {
                    try? path.deleteFile()
                }
                do {
                    try DataFile(path: path).write(response.data)
                } catch {
                    logger.warning("failed to write to \(path)")
                }

                let pageInfo = PageInfo.dummy
                assert(pageInfo.isLast)
                self.dataSyncEnd(for: table, with: pageInfo)

                if pageInfo.isLast, let process = self.process {
                    process.lock()
                    defer {
                        process.unlock()
                    }

                    // Set current table completed
                    process.completed(for: table, with: .success(pageInfo))
                    // Check if we must relaunch some request due to stamp
                    if let tableStatus = process.checkCompleted() {

                        // There is some table to relaunch sync because stamp are not equal
                        for (table, _) in tableStatus {
                            let c = self.reloadTable(table, in: path, queue: queue, progress: progress)
                            cancellable.append(c)
                        }
                    }
                }
            case .failure(let error):
                self.dataSyncFailed(for: table, with: APIError.error(from: error))

                if var process = self.process {
                    process.lock()
                    defer {
                        process.unlock()
                    }
                    self.process?.completed(for: table, with: .failureMappable(error))
                    _ = self.process?.checkCompleted()
                }
            }
        }

        let cancellableRecords = rest.request(target, queue: queue, progress: progress, completion: completion)
        cancellable.append(cancellableRecords)

        return cancellable
    }
}

extension PageInfo {

    public static let dummy = PageInfo(globalStamp: 0, sent: 10000, first: 0, count: 10000)
}
