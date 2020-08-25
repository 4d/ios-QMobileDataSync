//
//  DataDumpTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 12/09/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation


import XCTest
@testable import QMobileDataSync

import QMobileDataStore
import QMobileAPI

import FileKit

class DataDumpTests: XCTestCase {
    
    var dataSync: DataSync!
    
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
    
    func _testDataDump() {
        let expectation = self.expectation()

        let directory = Path.userTemporary + UUID().uuidString
        if !directory.exists {
           try? directory.createDirectory()
        }
        
        let test: () -> Void = {
            let ready = self.dataSync.dump(to: directory, with: .background) { _ in
                let children = directory.children()
                XCTAssertFalse(children.isEmpty)
                expectation.fulfill()
            }
            XCTAssertTrue(ready)
        }
        if dataSync.dataStore.isLoaded {
            test()
        } else {
            dataSync.dataStore.load { result in
                test()
            }
        }
        
        waitForExpectations(timeout: 10) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
        }
    }

    public func testPageInfoDummy() {
        XCTAssertTrue(PageInfo.dummy.isLast)
        XCTAssertTrue(PageInfo.dummy.isFirst)
    }

}
