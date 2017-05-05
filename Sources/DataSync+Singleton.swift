//
//  DataSync+Singleton.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 05/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation
import Moya

extension DataSync {
    // Default instance for DataSync, which use default data store and api manager
    public static let instance = DataSync()
}

extension DataSync {

    /// load table on default data sync instance
    public static func loadTable(_ completionHander: @escaping TablesCompletionHander) -> Cancellable {
        return self.instance.loadTable(completionHander)
    }

}
