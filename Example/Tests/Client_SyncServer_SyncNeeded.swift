//
//  Client_SyncServer_SyncNeeded.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 10/2/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_SyncNeeded: TestCase {
    override func setUp() {
        super.setUp()
        setupTest()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func syncNeeded(forSharingGroupUUID sharingGroupUUID: String) -> Bool? {
        let filteredGroups = SyncServer.session.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard filteredGroups.count == 1 else {
            XCTFail()
            return nil
        }
        
        return filteredGroups[0].syncNeeded
    }
    
    func testNewSharingGroupOnServer() {
        // Creates with the API-- so this is like a different client doing the creation.
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded1)
        
        // Now, when we do a sync with this sharing group, the syncNeeded should reset.
        SyncServer.session.eventsDesired = [.syncDone]

        let syncDone = self.expectation(description: "test2")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded2)
    }
    
    func sync(forSharingGroupUUID sharingGroupUUID: String) {
        SyncServer.session.eventsDesired = [.syncDone]

        let syncDone = self.expectation(description: "test")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    // sharing group updated on server (name change) by other client.
    func testSharingGroupUpdatedByAnotherClient() {
        let newSharingGroupName = UUID().uuidString

        guard let fileIndexResult = getFileIndex(sharingGroupUUID: nil),
            fileIndexResult.sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = fileIndexResult.sharingGroups[0]
        
        guard let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Just for a baseline-- so we have !syncNeeded at the start.
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded1)
        
        if let _ = updateSharingGroup(sharingGroupUUID: sharingGroup.sharingGroupUUID!, masterVersion: sharingGroup.masterVersion!, sharingGroupName: newSharingGroupName) {
            XCTFail()
            return
        }
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded2)
        
        // This will reset the syncNeeded flag.
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded3 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded3)
    }
    
    // New file or file version uploaded by another client. For a sharing group we already know about.
    func testNewFileUploadedByAnotherClient() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        // For a baseline-- so we have !syncNeeded at the start.
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded1)
        
        let fileUUID = UUID().uuidString
        let uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:uploadFileURL, mimeType: .text,  sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded2)
        
        // Download the file; flag should get reset.
        syncServerFileGroupDownloadComplete = nil
        
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded3 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded3)
    }
    
    func testNewFileVersionUploadedByAnotherClient() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded1)
        
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: attr.mimeType,  sharingGroupUUID: sharingGroupUUID, fileUUID: attr.fileUUID, serverMasterVersion: masterVersion, fileVersion: 1, fileGroupUUID: attr.fileGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded2)
        
        // Download the file version; flag should get reset.
        syncServerFileGroupDownloadComplete = nil
        
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded3 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded3)
    }
    
    // App meta data for a file uploaded by another client; For a sharing group we already know about.
    func testAppMetaDataUploadedByAnotherClient() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded1)
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let appMetaData = AppMetaData(version: 0, contents: "Foo123Bar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: attr.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded2)
        
        // Download the app meta data; flag should get reset.
        syncServerFileGroupDownloadComplete = nil
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded3 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded3)
    }

    // File deletion by another client; For a sharing group we already know about.
    func testFileDeletionByAnotherClient() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let syncNeeded1 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded1)
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: attr.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let syncNeeded2 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(syncNeeded2)
        
        // Download the deletion; flag should get reset.
        syncServerFileGroupDownloadComplete = nil
        sync(forSharingGroupUUID: sharingGroupUUID)
        
        guard let syncNeeded3 = syncNeeded(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(!syncNeeded3)
    }
}
