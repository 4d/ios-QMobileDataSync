//
//  TableStampStorage.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI
import Prephirences


class DataStoreTableStampStorageTests: XCTestCase {
    
    
    override func setUp() {
        super.setUp()
    
        Bundle.dataStore = Bundle(for: DataSyncTests.self)
        Bundle.dataStoreKey = "CoreDataModel"

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetAndSetGlobalStamp() {
        let exp = self.expectation()

        let future = DataStoreFactory.dataStore.load()
        future.onSuccess {
            guard let metadata = DataStoreFactory.dataStore.metadata else {
                XCTFail("Metadata not available")
                return
            }
            let storage = metadata.stampStorage
            self.testGetAndSetGlobalStamp(storage)
         
            exp.fulfill()
        }
        future.onFailure { error in
            XCTFail("\(error)")
        }
        waitExpectation()
    }
    
    func testGetAndSetGlobalStamp(_ storage: TableStampStorage) {
        var storage = storage
        XCTAssertEqual(storage.globalStamp, defaultStamp)
        
        let newValue = 50
        storage.globalStamp = newValue
        XCTAssertEqual(storage.globalStamp, newValue)
    }

    func testGetAndSetLastSync(_ storage: TableStampStorage) {
        var storage = storage

        let newValue = Date()
        storage.lastSync = newValue
        XCTAssertEqual(storage.lastSync, newValue)
    }
}
