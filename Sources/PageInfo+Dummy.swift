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
    static let dummy = PageInfo(globalStamp: 0, sent: Prephirences.DataSync.Request.limit, first: 0, count: Prephirences.DataSync.Request.limit)
}
