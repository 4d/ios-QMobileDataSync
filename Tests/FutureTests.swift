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

import Combine

class FutureTest: XCTestCase {
    
    var dataSync: DataSync!
    let timeout: TimeInterval = 8
    var bag: Any?
    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: DataSyncTests.self)
        
        Bundle.dataStore = bundle
        Bundle.dataStoreKey = "CoreDataModel"
        
        Bundle.qMobileApiStub = bundle
        Bundle.qMobileApiStubURL = Utils.testTargetPath
        
        let apiManager = APIManager.instance
        apiManager.stub = RemoteConfig.stub
        apiManager.stubDelegate = RemoteConfig.instance
        let dataStore = DataStoreFactory.dataStore
        
        dataSync = DataSync(apiManager: apiManager, dataStore: dataStore)
        dataSync.bundle = bundle
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testOneFutureStatus() {
        let expectation = self.expectation()
        
        let future = dataSync.apiManager.status(callbackQueue: .background)
        bag = future.onComplete { result in
            expectation.fulfill()
        }.sink()
        
        waitExpectation(timeout: timeout)
    }

    func testFutureResultify() {
        let expectation = self.expectation()
        
        let future = dataSync.apiManager.status(callbackQueue: .background).resultify()
        bag = future.onComplete { result in
            expectation.fulfill()
        }.sink()
        
        waitExpectation(timeout: timeout)
    }

}

