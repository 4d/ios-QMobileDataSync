//
//  ServerStatusTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI

import Combine

class ServerStatusTest: XCTestCase {
    
    var dataSync: DataSync!
    let timeout: TimeInterval = 20
    
    override func setUp() {
        
        super.setUp()
        Utils.initialize()
        
        Bundle.dataStore = Bundle.test
        Bundle.dataStoreKey = "CoreDataModel"
        
        Bundle.qMobileApiStub = Bundle.test
        Bundle.qMobileApiStubURL = Utils.testTargetPath
        
        let apiManager = APIManager.instance
        apiManager.stub = RemoteConfig.stub
        apiManager.stubDelegate = RemoteConfig.instance
        let dataStore = DataStoreFactory.dataStore
        
        dataSync = DataSync(apiManager: apiManager, dataStore: dataStore)
        dataSync.bundle = Bundle.test
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testOneFuturStatus() {
        let expectation = self.expectation()
        
        let future = dataSync.apiManager.status()
        _ = future.onComplete { result in
            expectation.fulfill()
        }.sink()
        
        waitExpectation(timeout: timeout)
    }

    func testStatusURL() {
        let expectation = self.expectation()
    
        let strings = ["http://localhost", "http://127.0.0.1"]
        let urls = strings.compactMap { URL(string: $0) }
        
        let future = APIManager.status(for: urls, callbackQueue: .background) { progress in
            print("\(progress)")
        }
        _ = future.receive(on: DispatchQueue.background).onComplete { result in
            
            switch result {
            case .success(let subResult):
                XCTAssertEqual(subResult.count, urls.count)
            case .failure:
                XCTFail("Not error expected")
            }
            expectation.fulfill()
        }.sink()
        
        waitExpectation(timeout: timeout)
    }
    
  /*  func testStatusURLFirstCompleted() {
        let expectation = self.expectation()
        
        let strings = ["http://test", "http://127.0.0.1"]
        let urls = strings.compactMap { URL(string: $0) }
        
        let future = APIManager.firstStatus(for: urls, callbackQueue: .background) { progress in
            print("\(progress)")
        }
        future.onComplete(DispatchQueue.background.context) { result in

            expectation.fulfill()
        }
        
        waitExpectation(timeout: timeout)
    }

    func testStatusURLFirstSuccess() {
        let expectation = self.expectation()
        
        let strings = ["http://test", "http://127.0.0.1"]
        let urls = strings.compactMap { URL(string: $0) }

        let future = APIManager.firstStatusSuccess(for: urls, callbackQueue: .background) { progress in
            print("\(progress)")
        }
        future.onComplete(DispatchQueue.background.context) { result in
            switch result {
            case .success(let res):
                let url: URL = res.0
                let status: Status = res.1
                XCTAssertEqual(url, URL(string: "http://127.0.0.1")!)
                XCTAssertTrue(status.ok)
                print("\(res)")
            case .failure(let error):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        
        waitExpectation(timeout: timeout * 5)
    }*/

    
}

