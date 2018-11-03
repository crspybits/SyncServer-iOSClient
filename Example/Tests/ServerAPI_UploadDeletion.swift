//
//  ServerAPI_UploadDeletion.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/19/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerAPI_UploadDeletion: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatUploadDeletionActuallyUploadsTheDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadDeletion(sharingGroupUUID: sharingGroupUUID)
    }
    
    func testThatTwoUploadDeletionsOfTheSameFileWork() {
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
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)

        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)

        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID
        ]) { fileInfo in
            XCTAssert(fileInfo.deleted)
        }
    }
    
    // TODO: *0* Do an upload deletion, then a second upload deletion with the same file-- make sure the 2nd one fails.
    
    func testThatActualDeletionInDebugWorks() {
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
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        var fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        fileToDelete.actualDeletion = true
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: []) { fileInfo in
            XCTAssert(fileInfo.fileUUID != fileUUID)
        }
    }
    
    func testDeleteAllServerFiles() {
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
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
    
        sharingGroups.forEach { sharingGroup in
            let sharingGroupUUID = sharingGroup.sharingGroupUUID
            removeAllServerFilesInFileIndex(sharingGroupUUID: sharingGroupUUID)
            getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: []) { fileInfo in
                XCTFail()
            }
        }
    }
}
