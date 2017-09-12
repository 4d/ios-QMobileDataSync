//
//  FutureTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 30/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI
import Result
import BrightFutures

class FutureTest: XCTestCase {
    
    var dataSync: DataSync!
    let timeout: TimeInterval = 8
    
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
    
    func _testOneFutureStatus() {
        let expectation = self.expectation()
        
        let future = dataSync.rest.loadStatus()
        future.onComplete { result in
            expectation.fulfill()
        }
        
        waitExpectation(timeout: timeout)
    }
    
    func testFutureResultify() {
        let expectation = self.expectation()
        
        let future = dataSync.rest.loadStatus().resultify()
        future.onComplete { result in
            expectation.fulfill()
        }
        
        waitExpectation(timeout: timeout)
    }
    
}
