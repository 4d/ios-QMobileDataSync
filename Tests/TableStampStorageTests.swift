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


class TableStampStorageTests: XCTestCase {
    
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetAndSetGlobalStamp() {
        let mutable: MutableDictionaryPreferences = [:]
        let storage = PrephirencesTableStampStorage(preferences: mutable)
        testGetAndSetGlobalStamp(storage)
    }
    
    func testGetAndSetGlobalStamp(_ storage: TableStampStorage) {
        var storage = storage
        XCTAssertEqual(storage.globalStamp, defaultStamp)
        
        let newValue = 50
        storage.globalStamp = newValue
        XCTAssertEqual(storage.globalStamp, newValue)
    }
    
    
}
