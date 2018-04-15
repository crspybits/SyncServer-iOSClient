//
//  Client_SyncServer_AppMetaData.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 4/8/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_AppMetaData: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Upload a file, with nil appMetaData-- make sure doesn't change current appMetaDataVersion, e.g., in the local directory entry.
    func testNilAppMetaDataDoesNotChangeLocalDirectoryAppMetaData() {
        let fileUUID = UUID().uuidString
        let appMetaData1 = "foobar"
        guard let _ = uploadSingleFileUsingSync(fileUUID:fileUUID, appMetaData: appMetaData1) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadSingleFileUsingSync(fileUUID:fileUUID) else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == appMetaData1)
            XCTAssert(directoryEntries[0].appMetaDataVersion == 0)
        }
    }
    
    // Upload a file, with non-nil appMetaData-- make sure updates current appMetaDataVersion, e.g., in the local directory entry.
    func testNonNilAppMetaDataChangesLocalDirectoryAppMetaData() {
        let fileUUID = UUID().uuidString
        let appMetaData1 = "foobar1"
        guard let _ = uploadSingleFileUsingSync(fileUUID:fileUUID, appMetaData: appMetaData1) else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == appMetaData1)
            XCTAssert(directoryEntries[0].appMetaDataVersion == 0)
        }
        
        let appMetaData2 = "foobar2"
        guard let _ = uploadSingleFileUsingSync(fileUUID:fileUUID, appMetaData: appMetaData2) else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == appMetaData2)
            XCTAssert(directoryEntries[0].appMetaDataVersion == 1)
        }
    }
    
    // Download a file with nil appMetaData-- must have nil appMetaDataVersion
    func testNilAppMetaDataOnDownloadWorks() {
        guard let fileUUID = doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text) else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == nil)
            XCTAssert(directoryEntries[0].appMetaDataVersion == nil)
        }
    }
    
    // Download a file with non-nil appMetaData-- must have non-nil appMetaDataVersion
    func testNonNilAppMetaDataOnDownloadWorks() {
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        guard let fileUUID = doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, appMetaData: appMetaData) else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == appMetaData.contents)
            XCTAssert(directoryEntries[0].appMetaDataVersion == appMetaData.version)
        }
    }
    
    // Download a purely app meta data update-- so that I get the delegate callback.
    func testAppMetaDataOnlyDownloadWorks() {
        let fileUUID = UUID().uuidString
        guard let _ = uploadSingleFileUsingSync(fileUUID:fileUUID) else {
            XCTFail()
            return
        }

        // Upload, not using sync, so our local file directory doesn't have the change.
        let masterVersion = getMasterVersion()
        let appMetaData = AppMetaData(version: 0, contents: "Foobar123")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        let expDone = self.expectation(description: "test1")
        let expAppMetaDataDownload = self.expectation(description: "test2")

        SyncServer.session.eventsDesired = [.syncDone]
        
        // Download-- expect appMetaData download only. This uses the new download appMetaData endpoint.
        syncServerAppMetaDataDownloadComplete = { attr in
            XCTAssert(appMetaData.contents == attr.appMetaData)
            expAppMetaDataDownload.fulfill()
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testAppMetaDataOnlyUploadWorks() {
        let fileUUID = UUID().uuidString
        guard let (_, attr) = uploadSingleFileUsingSync(fileUUID:fileUUID) else {
            XCTFail()
            return
        }
        
        let expDone = self.expectation(description: "test1")
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        var updatedAttr = attr
        updatedAttr.appMetaData = "123Foobar"
        // Uses the new app meta data upload endpoint.
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)
        SyncServer.session.sync()

        waitForExpectations(timeout: 20.0, handler: nil)
        
        let masterVersion = getMasterVersion()
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaDataContents == updatedAttr.appMetaData)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == updatedAttr.appMetaData)
            XCTAssert(directoryEntries[0].appMetaDataVersion == 0)
        }
    }
    
    func testVersion1AppMetaDataOnlyUploadWorks() {
        // Upload appMetaData version 0
        let fileUUID = UUID().uuidString
        let appMetaData1 = "FirstAppMetaData"
        guard let (_, attr) = uploadSingleFileUsingSync(fileUUID:fileUUID, appMetaData:appMetaData1) else {
            XCTFail()
            return
        }
        
        let expDone = self.expectation(description: "test1")
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        // Upload appMetaData version 1
        var updatedAttr = attr
        updatedAttr.appMetaData = "123Foobar"
        // Uses the new app meta data upload endpoint.
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)
        SyncServer.session.sync()

        waitForExpectations(timeout: 20.0, handler: nil)
        
        let masterVersion = getMasterVersion()
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 1, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaDataContents == updatedAttr.appMetaData)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == updatedAttr.appMetaData)
            XCTAssert(directoryEntries[0].appMetaDataVersion == 1)
        }
    }
    
    func testUploadThenAppMetaDataUploadRemovesUpload() {
        let fileUUID = UUID().uuidString

        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .appMetaData)
        }
    }
    
    func testAppMetaDataUploadThenUploadRemovesAppMetaDataUpload() {
        let fileUUID = UUID().uuidString
        guard let (url, attr) = uploadSingleFileUsingSync(fileUUID:fileUUID) else {
            XCTFail()
            return
        }
                
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .file)
        }
    }
    
    func testAppMetaDataUploadThenAppMetaDataUploadRemovesFirst() {
        let fileUUID = UUID().uuidString
        guard let (_, attr) = uploadSingleFileUsingSync(fileUUID:fileUUID) else {
            XCTFail()
            return
        }
        
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar1"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        updatedAttr.appMetaData = "foobar2"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .appMetaData)
            XCTAssert(ufts[0].appMetaData == updatedAttr.appMetaData)
        }
    }
}
