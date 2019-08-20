//
//  SequenceTests.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 03/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import XCTest
@testable import QMobileDataSync


class SequenceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testEmptyResultSequence() {
        let arrayOfResult: [Result<String, Never>] = []
        let result: Result<[String], Never> = arrayOfResult.result
        switch result {
        case .success(let array):
            XCTAssertEqual(array.count, arrayOfResult.count)
        case .failure:
            XCTFail("empty must not fail")
        }
        
        XCTAssertNil(arrayOfResult.values)
        XCTAssertNil(arrayOfResult.errors)
    }
    
    func testOneResultSequenceSuccess() {
        let data = "test"
        let arrayOfResult: [Result<String, Never>] = [.success(data)]
        let result: Result<[String], Never> = arrayOfResult.result
        switch result {
        case .success(let array):
            XCTAssertEqual(array.count, arrayOfResult.count)
            XCTAssertEqual(array.first, data)
        case .failure:
            XCTFail("must not fail")
        }
        
        XCTAssertNotNil(arrayOfResult.values)
        XCTAssertEqual(arrayOfResult.values?.count ?? 0, arrayOfResult.count)
        XCTAssertNil(arrayOfResult.errors)
    }
    
    func testOneResultSequenceFailure() {
        let data = NSError(domain: "test", code: 5)
        let arrayOfResult: [Result<String, NSError>] = [.failure(data)]
        let result: Result<[String], NSError> = arrayOfResult.result
        switch result {
        case .success:
            XCTFail("must not success")
        case .failure(let error):
            XCTAssertEqual(error, data)
        }
        
        XCTAssertNotNil(arrayOfResult.errors)
        XCTAssertEqual(arrayOfResult.errors?.count ?? 0, arrayOfResult.count)
        XCTAssertNil(arrayOfResult.values)
    }

    func testMixedResultSequenceSuccess() {
        let data = "test"
        let data2 = NSError(domain: "test", code: 5)
        let arrayOfResult: [Result<String, NSError>] = [.success(data),.failure(data2)]
        let result: Result<[String], NSError> = arrayOfResult.result
        switch result {
        case .success(_):
            XCTFail("must not success")
        case .failure(let error):
            XCTAssertEqual(error, data2)
        }
        
        XCTAssertNotNil(arrayOfResult.errors)
        XCTAssertNotNil(arrayOfResult.values)
        XCTAssertEqual(arrayOfResult.errors?.count ?? 0, 1)
        XCTAssertEqual(arrayOfResult.values?.count ?? 0, 1)

    }
    
    func testResultSequenceOnlySuccess() {
        let data = "test"
        let data2 = "test2"
        let arrayOfResult: [Result<String, Never>] = [.success(data),.success(data2)]
        let result: Result<[String], Never> = arrayOfResult.result
        switch result {
        case .success(let array):
            XCTAssertEqual(array.count, arrayOfResult.count)
            XCTAssertEqual(array, [data, data2])
        case .failure:
            XCTFail("must not fail")
        }
        
        XCTAssertNotNil(arrayOfResult.values)
        XCTAssertEqual(arrayOfResult.values?.count ?? 0, arrayOfResult.count)
        XCTAssertNil(arrayOfResult.errors)
    }

    func testResultSequenceOnlyFailure() {
        let data = NSError(domain: "test", code: 5)
        let data2 = NSError(domain: "test", code: 8)
        let arrayOfResult: [Result<String, NSError>] = [.failure(data),.failure(data2)]
        let result: Result<[String], NSError> = arrayOfResult.result
        switch result {
        case .success(_):
            XCTFail("must not success")
        case .failure(let error):
            XCTAssertEqual(error, data) // the first error
        }
        XCTAssertNotNil(arrayOfResult.errors)
        XCTAssertEqual(arrayOfResult.errors?.count ?? 0, arrayOfResult.count)
        XCTAssertNil(arrayOfResult.values)
    }
    
}
