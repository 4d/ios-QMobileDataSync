//
//  DataReloadTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 30/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//


import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI
import Result


class DataReloadTests: XCTestCase {
    
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
        let dataStore = DataStoreFactory.dataStore
        
        dataSync = DataSync(rest: apiManager, dataStore: dataStore)
        dataSync.bundle = bundle
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDataReload() {
        let lastSync = dataSync.dataStore.metadata?.lastSync ?? Date()
        let expectation = self.expectation()
        let cancellable = dataSync.reload { result in
            do {
                try result.dematerialize()
                
                let date = self.dataSync.dataStore.metadata?.lastSync
                XCTAssertNotNil(date, "no lastSync date")
                
                XCTAssertTrue(lastSync < date!)

                let result = self.dataSync.dataStore.perform(.background) { context in
                    do {
                        var count = try context.count(in: RemoteConfig.tableName)
                        XCTAssertEqual(count, 100, RemoteConfig.tableName)
                        
                        count = try context.count(in: "PRODUCTS")
                        XCTAssertEqual(count, 100, "PRODUCTS")

                        context.commit { _ in
                            // Check if synchronized to foreground context
                            let result = self.dataSync.dataStore.perform(.foreground) { foregroundContext in
                                    do {
                                        var count = try foregroundContext.count(in: RemoteConfig.tableName)
                                        XCTAssertEqual(count, 100, RemoteConfig.tableName)

                                        count = try foregroundContext.count(in: "PRODUCTS")
                                        XCTAssertEqual(count, 100, "PRODUCTS")
                                    } catch {
                                        XCTFail("\(error)")
                                    }
                                    expectation.fulfill()
                            }
                            XCTAssertEqual(result, true, "unable to perform request")
                        }
                    } catch {
                        XCTFail("\(error)")
                    }
                    
                }
                XCTAssertEqual(result, true, "unable to perform request")
            }
            catch {
                if case .apiError(let apiError) = error as? DataSyncError ?? .noTables {
                    if case .recordsDecodingFailed(let json, let parserError) = apiError {
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

    func testDataReloadCancelImmediately() {
        let expectation = self.expectation()
        let cancellable = dataSync.reload { result in
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
    
    func testDataReloadCancelInQueue() {
        let expectation = self.expectation()
        let cancellable = dataSync.reload { result in
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
    
    
    
    func testTwoSerialDataReload() {
        let expectation = self.expectation()
        let cancellable = dataSync.reload { result in
            do {
                try result.dematerialize()
                
                
                _ = self.dataSync.reload { result in
                    
                    let result = self.dataSync.dataStore.perform(.background) { context in
                        
                        do {
                            var count = try context.count(in: RemoteConfig.tableName)
                            XCTAssertEqual(count, 100, RemoteConfig.tableName)
                            
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
                    if case .recordsDecodingFailed(let json, let parserError) = apiError {
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

    public func testPageInfoDummy() {
        XCTAssertTrue(PageInfo.dummy.isLast)
        XCTAssertTrue(PageInfo.dummy.isFirst)
    }
    
}
