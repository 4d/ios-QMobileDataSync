//
//  Tests.swift
//  Tests
//
//  Created by Eric Marchand on 02/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI
import Result


class DataSyncTests: XCTestCase {
    
    var dataSync: DataSync!
    
    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: DataSyncTests.self)

        Bundle.dataStore = bundle
        Bundle.dataStoreKey = "CoreDataModel"
        
        Bundle.qMobileApiStub = bundle

        let apiManager = APIManager.instance
        apiManager.stub = RemoteConfig.stub
        apiManager.stubDelegate = RemoteConfig.instance
        let dataStore = QMobileDataStore.dataStore

        dataSync = DataSync(rest: apiManager, dataStore: dataStore)
        dataSync.bundle = bundle
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testLoadTable() {
        let expectation = self.expectation()
        
        let cancellable = dataSync.loadTable { result in
            do {
                let tables = try result.dematerialize()
                XCTAssertFalse(tables.isEmpty)
                
                if Bundle.dataStore[Bundle.dataStoreKey] as? String == "Invoices" {
                    XCTAssertEqual(tables.count, 3)
                }
                expectation.fulfill()
            }
            catch {
                XCTFail("\(error)")
            }
        }
        XCTAssertFalse(cancellable.isCancelled)
        
        waitExpectation()
    }
    
    func testDataSync() {
        let lastSync = dataSync.dataStore.metadata?.lastSync ?? Date()
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                
                let date = self.dataSync.dataStore.metadata?.lastSync
                XCTAssertNotNil(date, "no lastSync date")

                XCTAssertTrue(lastSync < date!)
                
                
               let result = self.dataSync.dataStore.perform(.background) { context, save in
                
                    do {
                        var count = try context.count(in: RemoteConfig.tableName)
                        XCTAssertEqual(count, 200, RemoteConfig.tableName)
                        
                         count = try context.count(in: "PRODUCTS")
                        XCTAssertEqual(count, 100, "PRODUCTS")
                        
                        expectation.fulfill()
                        
                    } catch {
                        
                        XCTFail("\(error)")
                    }
                    
                }
                XCTAssertEqual(result, true, "unable to perform request")
            }
            catch {
                if case .apiError(let apiError) = error as? DataSyncError ?? .noTables {
                    if case .recordsDecodingFailed(let json, let parserError) = apiError as? APIError ?? .dummy {
                        print("Not decodable \(json) \(parserError)")
                    }
                }
                XCTFail("\(error)")
            }
        }
        XCTAssertFalse(cancellable.isCancelled)
 
    
        waitForExpectations(timeout: 30) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
            print("\(String(describing: cancellable))")
        }
    }

    func testDataSyncCancelImmediately() {
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                
                XCTFail("Must have an exception")
            }
            catch {
                if case DataSyncError.cancel = error {
                    expectation.fulfill()
                } else {
                    XCTFail("\(error)")
                }
            }
        }
        cancellable.cancel()
        XCTAssertTrue(cancellable.isCancelled)
 
        waitForExpectations(timeout: 10) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
            print("\(String(describing: cancellable))")
        }
    }
 
    func testDataSyncCancelInQueue() {
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                
                // XCTFail("Must have an exception")
                expectation.fulfill() // difficult to test with stub
            }
            catch {
                if case DataSyncError.cancel = error {
                    expectation.fulfill()
                } else {
                    XCTFail("\(error)")
                }
            }
        }
        DispatchQueue.background.after(3) {
            cancellable.cancel()
            XCTAssertTrue(cancellable.isCancelled)
            
        }
        waitForExpectations(timeout: 10) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
            print("\(String(describing: cancellable))")
        }
    }

    func testTwoSerialDataSync() {
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                
                
                _ = self.dataSync.sync { result in
                    
                    let result = self.dataSync.dataStore.perform(.background) { context, save in
                        
                        do {
                            var count = try context.count(in: RemoteConfig.tableName)
                            XCTAssertEqual(count, 200, RemoteConfig.tableName)
                            
                            count = try context.count(in: "PRODUCTS")
                            XCTAssertEqual(count, 100, "PRODUCTS")
                            
                            expectation.fulfill()
                            
                        } catch {
                            
                            XCTFail("\(error)")
                        }
                        
                    }
                    XCTAssertEqual(result, true, "unable to perform request")
                    
                }
            }
            catch {
                if case .apiError(let apiError) = error as? DataSyncError ?? .noTables {
                    if case .recordsDecodingFailed(let json, let parserError) = apiError as? APIError ?? .dummy {
                        print("Not decodable \(json) \(parserError)")
                    }
                }
                XCTFail("\(error)")
            }
        }
        XCTAssertFalse(cancellable.isCancelled)

        waitForExpectations(timeout: 30) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
            print("\(String(describing: cancellable))")
        }
    }
    
    
    
    func testTwoSerialDataSyncWithDeleted() {
        DataSync.Preferences.deleteRecords = true
        defer {
                DataSync.Preferences.deleteRecords = false
        }
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                
                
                _ = self.dataSync.sync { result in
                    
                    let result = self.dataSync.dataStore.perform(.background) { context, save in
                        
                        do {
                            var count = try context.count(in: RemoteConfig.tableName)
                            XCTAssertEqual(count, 200, RemoteConfig.tableName)
                            
                            count = try context.count(in: "PRODUCTS")
                            XCTAssertEqual(count, 100, "PRODUCTS")
                            
                            expectation.fulfill()
                            
                        } catch {
                            
                            XCTFail("\(error)")
                        }
                        
                    }
                    XCTAssertEqual(result, true, "unable to perform request")
                    
                }
            }
            catch {
                if case .apiError(let apiError) = error as? DataSyncError ?? .noTables {
                    if case .recordsDecodingFailed(let json, let parserError) = apiError as? APIError ?? .dummy {
                        print("Not decodable \(json) \(parserError)")
                    }
                }
                XCTFail("\(error)")
            }
        }
        XCTAssertFalse(cancellable.isCancelled)
        
        
        waitForExpectations(timeout: 30) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
            print("\(String(describing: cancellable))")
        }
    }

    
}
