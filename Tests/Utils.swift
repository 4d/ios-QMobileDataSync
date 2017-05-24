//
//  Utils.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 29/03/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//
import XCTest
@testable import QMobileDataSync
import QMobileAPI

import Foundation
import SwiftyJSON

let tablesNames = ["CLIENTS", "INVOICES", "PRODUCTS"]

private class Utils {
    
}

// MARK: Files

func table(name: String) -> Table? {
    let bundle = Bundle(for: Utils.self)
    guard let url = bundle.url(forResource: "\(name).catalog", withExtension: "json") else {
        XCTFail("File not found to test \(name)")
        return nil
    }
    guard let data = try? Data(contentsOf: url, options: []) else {
        XCTFail("Failed to read data for table \(name) at url \(url)")
        return nil
    }
    let json = JSON(data: data)
    
    guard let table = Table(json: json) else {
        XCTFail("Failed to parse table \(name)")
        return nil
    }
    return table
}

func json(name: String) -> JSON? {
    let bundle = Bundle(for: Utils.self)
    guard let url = bundle.url(forResource: "\(name)", withExtension: "json") else {
        XCTFail("File not found to test \(name) data")
        return nil
    }
    guard let data = try? Data(contentsOf: url, options: []) else {
        XCTFail("Failed to read data for table \(name) at url \(url)")
        return nil
    }
    return JSON(data: data)
}

func json(name: String, id: String) -> JSON? {
    let bundle = Bundle(for: Utils.self)
    guard let url = bundle.url(forResource: "\(name)(\(id))", withExtension: "json") else {
        XCTFail("File not found to test \(name) data")
        return nil
    }
    guard let data = try? Data(contentsOf: url, options: []) else {
        XCTFail("Failed to read data for table \(name) at url \(url)")
        return nil
    }
    return JSON(data: data)
}


extension XCTestCase {
    
    open func expectation(function: String = #function) -> XCTestExpectation{
        return self.expectation(description: function)
    }
    
    open func waitExpectation(timeout: TimeInterval = 5) {
        waitForExpectations(timeout: timeout) { e in
            if let error = e {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    open func `try`(_ block: () throws -> Void) {
        do {
            try block()
        } catch {
            XCTFail("\(error)")
        }
    }
    
}
