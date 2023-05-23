# QMobileDataSync

This iOS framework synchronize the data from 4D database to the mobile database [QMobileDataStore](https://github.com/4d/ios-QMobileDataStore), by using [4D Rest API](https://developer.4d.com/docs/REST/gettingStarted) through [QMobileAPI](https://github.com/4d/ios-QMobileAPI)

Part of [iOS SDK](https://github.com/4d/ios-sdk)

## How it work

`DataSync` instance have some methods to synchronize (or reload) the data. 

1/ This methods loop on available tables on native mobile database, get latest data from 4D using the rest api and by specifying the stamp of modification, then store it in the native database

2/ Then at the end deleted records/entities are synchronized by getting data from table `__DeletedRecords`

## Dependencies

| Name | License | Usefulness |
|-|-|-|
| [QMobileAPI](https://github.com/4d/ios-QMobileAPI) | [4D](https://github.com/4d/ios-QMobileAPI/blob/master/LICENSE.md) | Network api |
| [QMobileDataStore](https://github.com/4d/ios-QMobileDataStore) | [4D](https://github.com/4d/ios-QMobileDataStore/blob/master/LICENSE.md) | Store data |

## Build

### Using Xcode project

To download dependencies use `carthage checkout`

then open workspace with Xcode and compile

### Using swift package manager

You can open [Package.swift](Package.swift) with Xcode and compile or launch standards command line for swift, see [build.sh](build.sh)
