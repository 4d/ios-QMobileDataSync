//
//  PageInfo.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation

import Prephirences

import QMobileAPI

extension PageInfo {
    /// A dummy page info.
    static let dummy = PageInfo(globalStamp: 0, sent: Prephirences.DataSync.Request.limit, first: 0, count: Prephirences.DataSync.Request.limit)

    /// A page to ignore when checking global stamp
    static let ignored = PageInfo(globalStamp: PageInfo.ignoredGlobalStamp, sent: Prephirences.DataSync.Request.limit, first: 0, count: Prephirences.DataSync.Request.limit)

    /// Stamp value for ignored table
    static let ignoredGlobalStamp = -1

}
