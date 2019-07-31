//
//  QMobileAPIDataStoreTests.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 29/03/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import XCTest
@testable import QMobileDataSync

import QMobileAPI
import QMobileDataStore

import CoreData

class DataStoreIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()

        Bundle.dataStore = Bundle(for: DataStoreIntegrationTests.self)
        Bundle.dataStoreKey = "CoreDataModel"

        let dataStore = DataStoreFactory.dataStore
        if !dataStore.isLoaded { // XXX not thread safe if parallel test
            let exp =  expectation(description: "dataStoreLoaded")
            dataStore.load { result in
                switch result {
                case .failure(let error):
                    XCTFail("Error \(error)")
                case .success:
                    break
                }

                exp.fulfill()
            }
            wait(for: [exp], timeout: 5)
            XCTAssertTrue(dataStore.isLoaded)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()

        /* if dataStore.isLoaded {*/
        let exp = expectation(description: "dataStoreLoaded")
        let dataStore = DataStoreFactory.dataStore
        dataStore.drop { result in
            switch result {
            case .failure(let error):
                XCTFail("Error \(error)")
            case .success:
                break
            }
            
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
       /* }*/
    }

    // function done to make TDD , real dev is in Parser, could be commented if all the parser test work done
    func testJSONRecords() {
        let dataStore = DataStoreFactory.dataStore
        for tableName in tablesNames {
            if let json = json(name: tableName), let table = table(name: tableName) {

                let entityModel = json[RestKey.entityModel].string
                XCTAssertEqual(entityModel, tableName, "incoherente table name")

                let count = json[RestKey.count].int ?? 0
                // let first = json["__FIRST"].int ?? 0
                let sent = json["__SENT"].int ?? 0
                // let full = sent == count

                XCTAssertTrue(sent <= count)

                if let entities = json[RestKey.entities].array {

                    let count = entities.count
                    XCTAssertEqual(count, sent, "Incoherente data count sent")

                    print("Create records with name '\(tableName)' and count '\(count)'")
                    var expect = self.expectation(description: "Create entities (name: \(tableName), count: \(count))")
                    _ = dataStore.perform(.background) { context in

                        for entity in entities {
                            // let key = entity["__KEY"].int
                            // let stamp = entity["__STAMP"].int
                            // let timeStamp = entity["__TIMESTAMP"].string

                            if let record = context.create(in: tableName) {
                                if let dictionary = entity.dictionary {
                                    for (key, value) in dictionary {
                                        if let attribute = table[key] {
                                            let transformedValue = AttributeValueMapper.default.map(value.object, with: attribute)
                                            record[attribute.safeName] = transformedValue
                                        } else {
                                            // skip? log if not internal
                                        }
                                    }
                                }
                                do {
                                    try record.validateForInsert()
                                } catch {
                                    XCTFail("Entity not valid to insert \(error) in data store")
                                }
                                XCTAssertNotNil(record.store.managedObjectContext, "Entity not really inserted")
                                XCTAssertEqual(record.store.managedObjectContext, context as? NSManagedObjectContext, "Not coherent context")

                                print("Create record \(record)")
                            } else {
                                // XXX maybe stop to enqueue other entities...
                                if let _ = NSEntityDescription.entity(forEntityName: tableName, in: context as! NSManagedObjectContext) {
                                    XCTFail("No entity \(tableName) in model")
                                } else {
                                    XCTFail("No entity \(tableName) in data store")
                                }
                            }
                        }
                        try? context.commit()

                        let fetchRequest = dataStore.fetchRequest(tableName: tableName, sortDescriptors: nil)
                        let createdCount = try? context.count(for: fetchRequest)

                        XCTAssertEqual(count, createdCount, "Not all records created")

                        expect.fulfill()
                    }
                    let timeout: TimeInterval = 20 // could be proportional to TimeInterval(count)
                    wait(for: [expect], timeout: timeout)

                    expect = self.expectation(description: "Check created records count in new context")
                    _ = dataStore.perform(.background) { context in

                        let fetchRequest = dataStore.fetchRequest(tableName: tableName, sortDescriptors: nil)
                        let createdCount = try? context.count(for: fetchRequest)

                        XCTAssertEqual(count, createdCount, "Not all records created")

                        expect.fulfill()
                    }

                    wait(for: [expect], timeout: 2)
                } else {
                    XCTFail("No entities")
                }
            }

        }
    }

    func testJSONImportables() {
        var expects: [XCTestExpectation] = []
        for tableName in tablesNames {
            let expect = self.expectation(description: "Create entities in \(tableName)")
            expects.append(expect)
            if let json = json(name: tableName), let table = table(name: tableName) {

                let dataStore = DataStoreFactory.dataStore
                if DataSync.instance.tablesInfoByTable.isEmpty {
                    let tableInfos: [DataStoreTableInfo] = tablesNames.compactMap { dataStore.tableInfo(for: $0) }
                    DataSync.instance.tablesInfoByTable = tableInfos.dictionary(key: { $0.api })
                }
                _ = dataStore.perform(.background) { context in
                    let importables = try? table.parser.parseArray(json: json, with: TextDataStoreContextBuilder(context: context))

                    XCTAssertEqual(importables?.count ?? 0, 100)

                    expect.fulfill()
                }

            }
        }
        let timeout: TimeInterval = 20
        wait(for: expects, timeout: timeout)
    }

    func testJSONImportable() {
        let tableName = "CLIENTS"
        guard let table = table(name: tableName), let json = json(name: tableName, id: "2") else {
            XCTFail("No JSON \(tableName)(2) to test")
            return
        }

        let expect = self.expectation(description: "Create entities")
        let dataStore = DataStoreFactory.dataStore
        
        if DataSync.instance.tablesInfoByTable.isEmpty {
            let tableInfos: [DataStoreTableInfo] = tablesNames.compactMap { dataStore.tableInfo(for: $0) }
            DataSync.instance.tablesInfoByTable = tableInfos.dictionary(key: { $0.api })
        }
        
        _ = dataStore.perform(.background) { context in

            if let importable = context.create(in: tableName) {
                table.parser.parse(json: json, into: importable)

                // check imported
                for (_, attribute) in table.attributes {
                    if attribute.type.isStorage {
                        if let value = importable.get(attribute: attribute) {
                            // check with  json[key].object??

                            if let storageType = attribute.storageType, storageType == .image {
                                if let dico = value as? [String: Any] {
                                    let imageURI = ImportableParser.parseImage(dico)
                                    XCTAssertNotNil(imageURI, "not URI for image in data")
                                } else {
                                    XCTFail("Image storage is not a dictionary")
                                }
                            }

                        } else {
                            XCTFail("No value for attribute \(attribute)")
                        }
                    }

                }

                // test unknown attribute
                // let fakeAttribute = Attribute(name: "fakeName", kind: .storage, scope: .public, type: AttributeStorageType.string )
                //XCTAssertNil(importable.get(attribute: fakeAttribute))
            }

            expect.fulfill()
        }
        let timeout: TimeInterval = 20
        wait(for: [expect], timeout: timeout)
    }
    
    func _testSetAttributeRelationship() {
        
        let mapper: AttributeValueMapper = .default
        let tableNameForce: String? = nil

        let tableName = "INVOICES"

        guard var table = table(name: tableName) else {
            XCTFail("No catalog \(tableName) to test")
            return
        }
        
        guard let json = json(name: "\(tableName)") else {
            XCTFail("No JSON \(tableName) to test")
            return
        }
        
        table.attributes["Link_5_return"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_5_return", decoded: "product", name: "Link_5_return")
        table.attributes["Link_4"]?.nameTransformer = AttributeNameTransformer(encoded: "Link_4", decoded: "client", name: "Link_4")
        
        let dataStore = DataStoreFactory.dataStore
        if DataSync.instance.tablesInfoByTable.isEmpty {
            let tableInfos: [DataStoreTableInfo] = tablesNames.compactMap { dataStore.tableInfo(for: $0) }
            DataSync.instance.tablesInfoByTable = tableInfos.dictionary(key: { $0.api })
        }
        
        let expect = self.expectation(description: "Create entities")
        _ = dataStore.perform(.background) { context in
            
            if let importable = context.create(in: tableName) {
                
                let jsonEntity: JSON
                if let entities = json[ImportKey.entities].array?.first {
                    jsonEntity = entities
                } else {
                    jsonEntity = json
                }
                
                XCTAssertNil(importable["client"])
                
                if let dictionary = jsonEntity.dictionary?.filter({ !$0.key.hasPrefix(ImportKey.reserved) }) {
                    for (key, jsonValue) in dictionary {
                        if let attribute = table[key] ?? table.attribute(forSafeName: key) {
                            importable.set(attribute: attribute, value: jsonValue.object, with: mapper)
                        } else {
                            XCTFail("Field '\(key)' not defined in table \(tableNameForce ?? table.name) structure.")
                        }
                    }
                }
//
//                let selfId = importable["id"]
//                if let client = importable["client"] as? NSManagedObject, let invoices = client["invoices"] as? NSManagedObject {
//                    let invoiceId = invoices["id"]
//                    print("selfId= \(selfId)")
//                    print("invoiceId= \(invoiceId)")
////                    XCTAssertEqual(selfId, invoiceId)
//                } else {
//                    XCTAssertNotNil(importable["client"])
//                }
                
                // test unknown attribute
                // let fakeAttribute = Attribute(name: "fakeName", kind: .storage, scope: .public, type: AttributeStorageType.string )
                //XCTAssertNil(importable.get(attribute: fakeAttribute))
            }
            
            expect.fulfill()
        }
        let timeout: TimeInterval = 20
        wait(for: [expect], timeout: timeout)
    }

}
struct TextDataStoreContextBuilder: ImportableBuilder {
    typealias Importable = Record

    let context: DataStoreContext

    init(context: DataStoreContext) {
        self.context = context
    }

    func setup(in callback: @escaping () -> Void) {
        callback()
    }
    func build(_ tableName: String, _ json: JSON) -> Record? {
        guard let record = context.create(in: tableName) else { return nil }
        // could import json here
        return record
    }
    func teardown() {
    }
}
