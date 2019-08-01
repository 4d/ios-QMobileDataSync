//
//  DataStoreRelationInfo+Relation.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 25/07/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation
import QMobileAPI
import QMobileDataStore

private enum DataStoreRelationInfoUserInfoKey: String {
    case keyMapping // original name
    case path, reversePath
    case expand
}

extension DataStoreRelationInfo {

    fileprivate func userInfo(_ key: DataStoreRelationInfoUserInfoKey) -> Any? {
        return self.userInfo?[key.rawValue]
    }

    var originalName: String {
        return self.userInfo(.keyMapping) as? String ?? self.name
    }

    var api: Attribute {
        let destinationName = self.destinationTable?.originalName ?? ""
        var type = AttributeRelativeType(rawValue: isToMany ? "\(destinationName)\(AttributeRelativeType.suffix)": destinationName)
        type.isToMany = self.isToMany
        type.expand = self.userInfo(.expand) as? String
        let kind: AttributeKind = isToMany ? .relatedEntities: .relatedEntity

        let originalName = self.originalName
        var attribute = Attribute(
            name: originalName,
            kind: kind,
            scope: .public,
            type: type
        )
        attribute.path = self.userInfo(.path) as? String
        attribute.reversePath = self.userInfo(.reversePath) as? Bool ?? false
        if originalName != self.name {
            attribute.nameTransformer = AttributeNameTransformer(encoded: originalName, decoded: name)
        }

        return attribute
    }
}
