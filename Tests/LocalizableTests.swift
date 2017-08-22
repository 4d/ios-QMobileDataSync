//
//  LocalizeTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 22/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import XCTest
@testable import QMobileDataSync

class LocalizableTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDataSyncError() {
       
        let errors:[DataSyncError] = [.retain]
        for error in errors {
            let message = error.errorDescription
            
            XCTAssertFalse(message?.isEmpty ?? true, "\(error)")
            XCTAssertFalse(message?.contains("dataSync.") ?? true, "\(error) \(String(describing: message))")
        
        
            if let recover = error.recoverySuggestion {
                XCTAssertFalse(recover.isEmpty , "\(error)")
                XCTAssertFalse(recover.contains("dataSync."), "\(error) \(recover)")
            }
        }
    }

}
