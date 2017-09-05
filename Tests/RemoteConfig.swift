//
//  RemoteConfig.swift
//  QMobileAPI
//
//  Created by Eric Marchand on 28/04/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya
import QMobileAPI

class RemoteConfig {

    static let stub = true // TODO parametrize , maybe if ip not set
    
    static var tableName: String {
        return "CLIENTS"
    }
    
    static let instance = RemoteConfig()
    static let bundle = Bundle(for: RemoteConfig.self)
    
    init() {}

}

extension RemoteConfig: StubDelegate {

    public func sampleResponse(_ target: TargetType) -> Moya.EndpointSampleResponse? {
        
        if let recordsTarget = target as? RecordsTarget {
            let tableName = recordsTarget.table
 
            var fileName = tableName
            if let skip = recordsTarget.getParameter(.skip) {
                fileName = "\(tableName)_\(skip)"
                print("stub \(tableName) with skip \(skip)")
            }

            if let url = RemoteConfig.bundle.url(forResource: fileName, withExtension: "json", subdirectory: nil) {
                return try? Moya.EndpointSampleResponse.url(url)
            }
        }
        if let statusTarget = target as? StatusTarget {
             /*
            if let url = RemoteConfig.bundle.url(forResource: fileName, withExtension: "json", subdirectory: nil) {
                return try? Moya.EndpointSampleResponse.url(url)
            }
 statusTarget
 */
        }

        return nil
    }
    
}

extension Moya.EndpointSampleResponse {
    
    static func url(_ url: URL, _ code: Int = 200) throws -> Moya.EndpointSampleResponse  {
        // remove whn api implement it
        let data = try Data(contentsOf: url)
        return .networkResponse(code, data)
    }

}
