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

        let apiManager = APIManager(url: DataSync.Preferences.remoteServerURL)
        apiManager.stub = RemoteConfig.stub
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
        let expectation = self.expectation()
        let cancellable = dataSync.sync { result in
            do {
                try result.dematerialize()
                expectation.fulfill()
            }
            catch {
                XCTFail("\(error)")
            }
        }
        XCTAssertNotNil(cancellable)
        XCTAssertFalse(cancellable?.isCancelled ?? false)
        waitExpectation()
    }
    
}
