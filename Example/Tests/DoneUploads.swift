//
//  DoneUploads.swift
//  SyncServer
//
//  Created by Christopher Prince on 1/31/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerAPI_DoneUploads: TestCase {    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDoneUploadsWorksWithOneFile() {
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
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [fileUUID])
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [fileUUID])
        
        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [])
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDoneUploadsWorksWithTwoFiles() {
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
        let fileURL1 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL1, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        let fileURL2 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "Cat", withExtension: "jpg")!
        guard let _ = uploadFile(fileURL:fileURL2, mimeType: .jpeg, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }

        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID1, fileUUID2
        ])
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID1, fileUUID2
        ])
        
        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [])
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testThatUploadDeletionOfOneFileWithDoneUploadsActuallyDeletes() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadDeletionOfOneFileWithDoneUploads(sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDoneUploadsWith1FileUploadAnd1UploadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // This upload deletion has to happen 1st because it does a doneUploads, and we don't want `fileUUIDUpload` to be subject to doneUploads yet.
        guard let (fileUUIDDelete, masterVersion) = uploadDeletion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUIDUpload = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID:sharingGroupUUID, fileUUID: fileUUIDUpload, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }

        self.doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        var foundDeletedFile = false
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUIDUpload, fileUUIDDelete]) { file in
            if file.fileUUID == fileUUIDDelete {
                foundDeletedFile = true
                XCTAssert(file.deleted)
            }
        }
        
        XCTAssert(foundDeletedFile)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDoneUploadsConflict() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let deviceUUID1 = Foundation.UUID()
        let deviceUUID2 = Foundation.UUID()
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        deviceUUID = deviceUUID1
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
        
        deviceUUID = deviceUUID2
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
        
        let expectation1 = self.expectation(description: "doneUploads1")
        let expectation2 = self.expectation(description: "doneUploads2")
        
        var doneRequest1 = false
        
        deviceUUID = deviceUUID1 // for ServerAPIDelegate
        testLockSync = 5
        deviceUUIDUsed = false
        
        // A lock will be obtained by this first request.
        ServerAPI.session.doneUploads(serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) {
            doneUploadsResult, error in
            
            XCTAssert(error == nil)
            if case .success(let numberUploads) = doneUploadsResult! {
                XCTAssert(numberUploads == 1, "Number uploads = \(numberUploads)")
            }
            else {
                XCTFail()
            }
            
            Log.special("Finished doneUploads1")
            
            doneRequest1 = true
            expectation1.fulfill()
        }

        // Let above `doneUploads` request get started -- by delaying the 2nd request.
        TimedCallback.withDuration(1.0) {
        
            // The first request should have started, and obtained the lock. This second request will block until the first is done, because of the transactional implementation of the server.
            XCTAssert(self.deviceUUIDUsed)

            self.deviceUUID = deviceUUID2
            self.testLockSync = nil
            
            ServerAPI.session.doneUploads(serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) {
                doneUploadsResult, error in
                            
                XCTAssert(error == nil)
                guard case .serverMasterVersionUpdate(_) = doneUploadsResult! else {
                    XCTFail()
                    return
                }
                
                Log.special("Finished doneUploads2: \(String(describing: doneUploadsResult))")
                
                XCTAssert(doneRequest1)
                expectation2.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDoneUploadsWithDeletionChangesMasterVersion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID,  serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberDeletions: 1)
        masterVersion += 1
        
        // *Must* get master version from server here because local master version in SharingEntry's will not have been updated.
        guard let masterVersion2 = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        XCTAssert(masterVersion2 == masterVersion)

        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    // TODO: *2* I would like a test where there are concurrent DoneUploads operations-- across two users. e.g., users A and B each upload a file, and then concurrently do DoneUpload operatons-- this should not result in a lock/blocking situation, even with the transactional support because InnoDB does row level locking. (I'm not sure how to support access within a single iOS app by two Google users.)
    // This should be pretty much exactly like the above test, except (a) it should not result in locking/blocking, and (b) it should use two users not 1.
}


