//
//  DataSync+Future.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 16/05/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

import BrightFutures
import Result
import QMobileAPI

extension DataSync {

    public func loadTable() -> Future<[Table], APIError> {
        if !self.tablesByName.isEmpty {
            return Future<[Table], APIError>(result: .success(self.tables))
        }
        return Future { _ = self.loadTable($0) }
    }

}
