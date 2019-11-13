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

#if os(iOS)
import UIKit
#endif

import Foundation
import SwiftyJSON
import Prephirences

let tablesNames = ["CLIENTS", "INVOICES", "PRODUCTS"]

class Utils {
    
    static func initialize() {
        Prephirences.sharedInstance = MutableCompositePreferences([UserDefaults.standard, Bundle.test])
    }

    static let testTargetPath = URL(fileURLWithPath: #file)
          .deletingLastPathComponent()
          .deletingLastPathComponent()
}

extension Bundle {
    static let test = Bundle(for: Utils.self)
}

// MARK: Files

func table(name: String) -> Table? {
    let bundle = Bundle(for: Utils.self)

    #if os(iOS)
    if let json = NSDataAsset(name: "\(name).catalog", bundle: bundle)?.json {
        guard let table = Table(json: json) else {
            XCTFail("Failed to parse table \(name)")
            return nil
        }
        return table
    }
    #endif

    guard let url = bundle.url(forResource: "\(name).catalog", withExtension: "json") else {
        XCTFail("File not found to test \(name)")
        return nil
    }
    guard let data = try? Data(contentsOf: url, options: []) else {
        XCTFail("Failed to read data for table \(name) at url \(url)")
        return nil
    }

    guard let json = try? JSON(data: data), let table = Table(json: json) else {
        XCTFail("Failed to parse table \(name)")
        return nil
    }
    return table
}
extension NSDataAsset {
    var json: JSON? {
        return try? JSON(data: self.data)
    }
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
    do {
        return try JSON(data: data)
    } catch {
        XCTFail("Failed to parse data to JSON : \(error)")
    }
    return nil
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
    return try? JSON(data: data)
}


func createRelationLink(table: inout Table) {
    
    switch table.name {
    case "CLIENTS":
        table.attributes["Link_7_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_7_return", decoded: "products", name: "Link_7_return")
        table.attributes["Link_4_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_4_return", decoded: "invoices", name: "Link_4_return")
        
    case "INVOICES":
        table.attributes["Link_5_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_5_return", decoded: "products", name: "Link_5_return")
        table.attributes["Link_4"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_4", decoded: "client", name: "Link_4")
        
    case "PRODUCTS":
        table.attributes["Link_8_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_8_return", decoded: "client", name: "Link_8_return")
        table.attributes["Link_6_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_6_return", decoded: "invoice", name: "Link_6_return")
        
    default:
        break
    }
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
/*

extension NSError {
    static let dummy: NSError = NSError(domain: "dummy", code: 0)
    var isDummy: Bool {
        return domain == "dummy"
    }
}

extension APIError {
    //static let dummy: APIError = .request(NSError.dummy)
    var isDummy: Bool {
        switch self {
        case .request(let error):
            return (error as NSError).isDummy
        default:
            return false
        }
    }
}*/
