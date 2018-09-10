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
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Upload a file, with nil appMetaData-- make sure doesn't change current appMetaDataVersion, e.g., in the local directory entry.
    func testNilAppMetaDataDoesNotChangeLocalDirectoryAppMetaData() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        let appMetaData1 = "foobar"
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, appMetaData: appMetaData1) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        let appMetaData1 = "foobar1"
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, appMetaData: appMetaData1) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, appMetaData: appMetaData2) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let fileUUID = doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        guard let fileUUID = doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupUUID: sharingGroupUUID, appMetaData: appMetaData) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID) else {
            XCTFail()
            return
        }

        // Upload, not using sync, so our local file directory doesn't have the change.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar123")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        let expDone = self.expectation(description: "test1")
        let expAppMetaDataDownload = self.expectation(description: "test2")

        SyncServer.session.eventsDesired = [.syncDone]
        
        // Download-- expect appMetaData download only. This uses the new download appMetaData endpoint.
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .appMetaData = group[0].type {
                let attr = group[0].attr
                XCTAssert(appMetaData.contents == attr.appMetaData)
                expAppMetaDataDownload.fulfill()
            }
            else {
                XCTFail()
            }
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testAppMetaDataOnlyUploadWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID) else {
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
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaDataContents == updatedAttr.appMetaData)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload appMetaData version 0
        let fileUUID = UUID().uuidString
        let appMetaData1 = "FirstAppMetaData"
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, appMetaData:appMetaData1) else {
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
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 1, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaDataContents == updatedAttr.appMetaData)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString

        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .appMetaData)
        }
    }
    
    func testAppMetaDataUploadThenUploadRemovesAppMetaDataUpload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID) else {
            XCTFail()
            return
        }
                
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .file)
        }
    }
    
    func testAppMetaDataUploadThenAppMetaDataUploadRemovesFirst() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID) else {
            XCTFail()
            return
        }
        
        var updatedAttr = attr
        updatedAttr.appMetaData = "foobar1"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)

        updatedAttr.appMetaData = "foobar2"
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let ufts = try! Upload.pendingSync().uploadFileTrackers
            guard ufts.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(ufts[0].operation == .appMetaData)
            XCTAssert(ufts[0].appMetaData == updatedAttr.appMetaData)
        }
    }
    
    
    // Error case: Cannot upload v0 of a file using appMetaData upload.
    func testUploadV0FileWithAppMetaUploadFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        
        var attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        attr.appMetaData = "123Foobar"
        
        do {
            try SyncServer.session.uploadAppMetaData(attr: attr)
        } catch {
            return
        }
        
        XCTFail()
    }
}
