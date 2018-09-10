//
//  Client_FileGroup.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 5/9/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class Client_FileGroup: TestCase {
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Upload a file with nil group UUID for v0, and try to upload a non-nil for v1; should fail
    func testUploadNonNilGroupUUIDAfterNilFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString

        // Nil file group UUID
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString
        let result = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, fileGroupUUID: fileGroupUUID, errorExpected: .uploadImmutable)
        XCTAssert(result == nil)
    }
    
    // Upload a file with non-nil group UUID for v0, and try to upload a different non-nil group UUID for v1; should fail
    func testUploadDifferentNonNilGroupUUIDAfterNonNilFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        let fileGroupUUID1 = UUID().uuidString
        
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, fileGroupUUID: fileGroupUUID1) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID2 = UUID().uuidString
        let result = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, fileGroupUUID: fileGroupUUID2, errorExpected: .uploadImmutable)
        XCTAssert(result == nil)
    }
    
    // appMetaData upload of a file with a non-nil group-UUID for v1, where it's the same as previous-- should work
    func testAppMetaDataUploadWithSameNonNilGroupUUIDWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        let fileGroupUUID = UUID().uuidString

        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, fileGroupUUID: fileGroupUUID) else {
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
        updatedAttr.fileGroupUUID = fileGroupUUID
        try! SyncServer.session.uploadAppMetaData(attr: updatedAttr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // appMetaData upload of a file with a non-nil group-UUID for v1, where it's different than previous-- should fail.
    func testAppMetaDataUploadWithDifferentNonNilGroupUUIDFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        let fileGroupUUID1 = UUID().uuidString

        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID:fileUUID, fileGroupUUID: fileGroupUUID1) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID2 = UUID().uuidString
        var updatedAttr = attr
        updatedAttr.appMetaData = "123Foobar"
        updatedAttr.fileGroupUUID = fileGroupUUID2
        
        do {
            try SyncServer.session.uploadAppMetaData(attr: updatedAttr)
            XCTFail()
        } catch (let error) {
            Log.error("Expected-- \(error)")
        }
    }
    
    // When a file is downloaded for the first time and it has a group UUID, make sure the group UUID is stored in the directory.
    func testFirstDownloadStoresFileGroupUUID() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID

        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!
        let fileGroupUUID = UUID().uuidString

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
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

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let entries = DirectoryEntry.fetchAll()
            let filtered = entries.filter {$0.fileUUID == fileUUID}
            guard filtered.count == 1 else {
                XCTFail()
                return
            }
            XCTAssert(filtered[0].fileGroupUUID == fileGroupUUID)
        }
    }
    
    // Download v1 of a file as the first time a file is downloaded, and make sure the group UUID makes it into the directory.
    func testV1DownloadStoresFileGroupUUID() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        let fileGroupUUID = UUID().uuidString
        guard let file = uploadFileVersion(1, fileURL: fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileGroupUUID: fileGroupUUID) else {
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

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let entries = DirectoryEntry.fetchAll()
            let filtered = entries.filter {$0.fileUUID == file.fileUUID}
            guard filtered.count == 1 else {
                XCTFail()
                return
            }
            XCTAssert(filtered[0].fileGroupUUID == fileGroupUUID)
        }
    }
    
    // MARK: Group download tests
    
    // Download a group of files-- i.e., a collection of files with the same group UUID. The delegate callback should be called for exactly this group of files.
    func testDownloadGroupOfFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload a group of files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let groupDone = self.expectation(description: "test2")

        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTAssert(group.count == 2)
            
            group.forEach { file in
                guard case .file = file.type else {
                    XCTFail()
                    return
                }
                
                XCTAssert(file.attr.fileGroupUUID == fileGroupUUID)
                let filtered1 = group.filter {$0.attr.fileUUID == fileUUID1}
                let filtered2 = group.filter {$0.attr.fileUUID == fileUUID2}
                XCTAssert(filtered1.count == 1)
                XCTAssert(filtered2.count == 1)
            }
            groupDone.fulfill()
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Download a group of files-- i.e., a collection of files with the same group UUID. The delegate callback should be called for exactly this group of files. Include another file-- not in this group UUID-- delegate should get called separately for this.
    func testDownloadGroupOfFilesWithSeparateFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload a group of files.
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileUUID3 = UUID().uuidString
        
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        masterVersion += 1
        
        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID3, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let twoFileGroupDone = self.expectation(description: "test2")
        let oneFileGroupDone = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 2 {
                group.forEach { file in
                    guard case .file = file.type else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssert(file.attr.fileGroupUUID == fileGroupUUID)
                    let filtered1 = group.filter {$0.attr.fileUUID == fileUUID1}
                    let filtered2 = group.filter {$0.attr.fileUUID == fileUUID2}
                    XCTAssert(filtered1.count == 1)
                    XCTAssert(filtered2.count == 1)
                }
                twoFileGroupDone.fulfill()
            }
            else if group.count == 1 {
                guard case .file = group[0].type else {
                    XCTFail()
                    return
                }
                
                XCTAssert(group[0].attr.fileGroupUUID == nil)
                XCTAssert(group[0].attr.fileUUID == fileUUID3)
                oneFileGroupDone.fulfill()
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Downloading groups, with specific group UUID's, with just one file in them should work.
    func testSingleGroupSizeWithGroupUUIDs() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID1 = UUID().uuidString
        let fileGroupUUID2 = UUID().uuidString
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID1) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID2) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let oneFileGroupDone1 = self.expectation(description: "test2")
        let oneFileGroupDone2 = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .file = group[0].type else {
                XCTFail()
                return
            }
            
            if group[0].attr.fileUUID == fileUUID1 {
                XCTAssert(group[0].attr.fileGroupUUID == fileGroupUUID1)
                oneFileGroupDone1.fulfill()
            }
            else if group[0].attr.fileUUID == fileUUID2 {
                XCTAssert(group[0].attr.fileGroupUUID == fileGroupUUID2)
                oneFileGroupDone2.fulfill()
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // You should get the same effect when not giving a group UUID for the downloaded file-- it should act as a group of size 1.
    func testSingleGroupSizeWithoutGroupUUIDs() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let oneFileGroupDone1 = self.expectation(description: "test2")
        let oneFileGroupDone2 = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .file = group[0].type else {
                XCTFail()
                return
            }
            
            guard case .file = group[0].type else {
                XCTFail()
                return
            }
            
            if group[0].attr.fileUUID == fileUUID1 {
                XCTAssert(group[0].attr.fileGroupUUID == nil)
                oneFileGroupDone1.fulfill()
            }
            else if group[0].attr.fileUUID == fileUUID2 {
                XCTAssert(group[0].attr.fileGroupUUID == nil)
                oneFileGroupDone2.fulfill()
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testGroupWithOnlyADownloadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileGroupUUID = UUID().uuidString
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: attr.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // Get the download deletion with sync
        
        let expDone = self.expectation(description: "test1")
        let downloadDeletion = self.expectation(description: "test2")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            XCTAssert(group[0].attr.fileUUID == attr.fileUUID)
            
            downloadDeletion.fulfill()
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testGroupWithTwoDeletionWithSameGroupUUID() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileGroupUUID = UUID().uuidString

        guard let (_, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (_, attr2) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileToDelete1 = ServerAPI.FileToDelete(fileUUID: attr1.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete1, masterVersion: masterVersion)
        let fileToDelete2 = ServerAPI.FileToDelete(fileUUID: attr2.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete2, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Get the download deletions with sync
        
        let expDone = self.expectation(description: "test1")
        let downloadDeletion1 = self.expectation(description: "test2")
        let downloadDeletion2 = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 2 else {
                XCTFail()
                return
            }
            
            group.forEach { file in
                guard case .deletion = file.type else {
                    XCTFail()
                    return
                }
                
                if file.attr.fileUUID == attr1.fileUUID {
                    downloadDeletion1.fulfill()
                } else if file.attr.fileUUID == attr2.fileUUID {
                    downloadDeletion2.fulfill()
                }
                else {
                    XCTFail()
                }
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testGroupWithOnlyAnAppMetaDataUpdate() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileGroupUUID = UUID().uuidString
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData1, fileUUID: attr.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        // Get the app meta data update with sync
        
        let expDone = self.expectation(description: "test1")
        let downloadAppMetaData = self.expectation(description: "test2")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .appMetaData = group[0].type else {
                XCTFail()
                return
            }
            
            XCTAssert(group[0].attr.fileUUID == attr.fileUUID)
            XCTAssert(group[0].attr.appMetaData == appMetaData1.contents, "\(String(describing: group[0].attr.appMetaData))")

            downloadAppMetaData.fulfill()
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testGroupWithTwoAppMetaDataUpdatesWithSameGroupUUID() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileGroupUUID = UUID().uuidString

        guard let (_, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (_, attr2) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData1, fileUUID: attr1.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let appMetaData2 = AppMetaData(version: 0, contents: "Blarbar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData2, fileUUID: attr2.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Get the download app meta data updates with sync
        
        let expDone = self.expectation(description: "test1")
        let downloadAppMetaData1 = self.expectation(description: "test2")
        let downloadAppMetaData2 = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 2 else {
                XCTFail()
                return
            }
            
            group.forEach { file in
                guard case .appMetaData = file.type else {
                    XCTFail()
                    return
                }
                
                if file.attr.fileUUID == attr1.fileUUID {
                    XCTAssert(file.attr.appMetaData == appMetaData1.contents, "\(String(describing: file.attr.appMetaData))")
                    downloadAppMetaData1.fulfill()
                } else if file.attr.fileUUID == attr2.fileUUID {
                    XCTAssert(file.attr.appMetaData == appMetaData2.contents, "\(String(describing: file.attr.appMetaData))")
                    downloadAppMetaData2.fulfill()
                }
                else {
                    XCTFail()
                }
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // A download group with a version update, appMetaData download, and a deletion.
    func testGroupWithVersionUpdateAppMetaDataDownloadAndDeletions() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileGroupUUID = UUID().uuidString

        guard let (_, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (_, attr2) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (_, attr3) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID:fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: attr1.fileUUID, serverMasterVersion: masterVersion, fileVersion: 1) else {
            return
        }
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData1, fileUUID: attr2.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: attr3.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 3)
        
        // Get the download updates with sync
        
        let expDone = self.expectation(description: "test1")
        let versionUpdate = self.expectation(description: "test2")
        let appMetaData = self.expectation(description: "test3")
        let deletion = self.expectation(description: "test4")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 3 else {
                XCTFail()
                return
            }
            
            group.forEach { operation in
                if operation.attr.fileUUID == attr1.fileUUID {
                    guard case .file = operation.type else {
                        XCTFail()
                        return
                    }
                    versionUpdate.fulfill()
                } else if operation.attr.fileUUID == attr2.fileUUID {
                    guard case .appMetaData = operation.type else {
                        XCTFail()
                        return
                    }
                    XCTAssert(operation.attr.appMetaData == appMetaData1.contents, "\(String(describing: operation.attr.appMetaData))")
                    appMetaData.fulfill()
                } else if operation.attr.fileUUID == attr3.fileUUID {
                    guard case .deletion = operation.type else {
                        XCTFail()
                        return
                    }
                    deletion.fulfill()
                }
                else {
                    XCTFail()
                }
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Two separate groups with deletions-- nil group UUID in each case.
    func testTwoGroupsWithDeletionsWithNilGroupId() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (_, attr2) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileToDelete1 = ServerAPI.FileToDelete(fileUUID: attr1.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete1, masterVersion: masterVersion)
        
        let fileToDelete2 = ServerAPI.FileToDelete(fileUUID: attr2.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete2, masterVersion: masterVersion)
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Get the download updates with sync
        
        let expDone = self.expectation(description: "test1")
        let deletion1 = self.expectation(description: "test2")
        let deletion2 = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            if group[0].attr.fileUUID == attr1.fileUUID {
                deletion1.fulfill()
            }
            else if group[0].attr.fileUUID == attr2.fileUUID {
                deletion2.fulfill()
            }
            else {
                XCTFail()
            }
            
            XCTAssert(group[0].attr.fileGroupUUID == nil)
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // A group with a larger numbers of operations-- e.g., with 10 downloads.
    func testFileGroupWithLargerNumberOfOperations() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload a group of files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString
        let numberOfFiles = 10
        var fileUUIDs = [String]()
        
        for _ in 1...numberOfFiles {
            let fileUUID = UUID().uuidString
            fileUUIDs += [fileUUID]
        }

        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!

        for index in 0..<numberOfFiles {
            let fileUUID = fileUUIDs[index]
            guard let _ = uploadFile(fileURL:uploadFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
                return
            }
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: Int64(numberOfFiles))
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let groupDone = self.expectation(description: "test2")

        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTAssert(group.count == numberOfFiles)
            
            group.forEach { file in
                guard case .file = file.type else {
                    XCTFail()
                    return
                }
                
                XCTAssert(file.attr.fileGroupUUID == fileGroupUUID)
                
                guard let index = (fileUUIDs.index {$0 == file.attr.fileUUID}) else {
                    XCTFail()
                    return
                }
                
                fileUUIDs.remove(at: index)
            }
            
            XCTAssert(fileUUIDs.count == 0)
            
            groupDone.fulfill()
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Make sure the files have their expected contents.
    func testDownloadAGroupWithATextFileAndImageWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload a group of files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString

        let imageFileUUID = UUID().uuidString
        let textFileUUID = UUID().uuidString

        let textFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!
        let imageFileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "Cat", withExtension: "jpg")!

        guard let _ = uploadFile(fileURL:textFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: textFileUUID, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:imageFileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: imageFileUUID, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // Download them with sync
        
        let expDone = self.expectation(description: "test1")
        let expImage = self.expectation(description: "test2")
        let expText = self.expectation(description: "test3")
        
        SyncServer.session.eventsDesired = [.syncDone]

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expDone.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTAssert(group.count == 2)
            
            group.forEach { file in
                guard case .file(let url) = file.type else {
                    XCTFail()
                    return
                }
                
                XCTAssert(file.attr.fileGroupUUID == fileGroupUUID)
                
                if file.attr.fileUUID == textFileUUID {
                    XCTAssert(self.filesHaveSameContents(url1: url as URL, url2: textFileURL))
                    expText.fulfill()
                }
                else if file.attr.fileUUID == imageFileUUID {
                    XCTAssert(self.filesHaveSameContents(url1: url as URL, url2: imageFileURL))
                    expImage.fulfill()
                }
                else {
                    XCTFail()
                }
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
