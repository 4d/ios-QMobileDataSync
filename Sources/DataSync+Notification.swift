//
//  DataSync+Notification.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 18/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

public extension Notification.Name {

    // Notify data sync begin
    public static let dataSyncBegin = Notification.Name("dataSync.begin")
    // notify sync end with success
    public static let dataSyncSuccess = Notification.Name("dataSync.success")
    // notify sync failed
    public static let dataSyncFailed = Notification.Name("dataSync.failed")

    // sync begin for one table
    public static let dataSyncForTableBegin = Notification.Name("dataSync.table.begin")
    // each page is published
    public static let dataSyncForTableProgress = Notification.Name("dataSync.table.progress")
    // table sync end with success
    public static let dataSyncForTableSuccess = Notification.Name("dataSync.table.success")
    // table sync end with error
    public static let dataSyncForTableFailed = Notification.Name("dataSync.table.failed")

}
