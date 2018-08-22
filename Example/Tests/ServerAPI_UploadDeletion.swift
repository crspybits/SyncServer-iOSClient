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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatUploadDeletionActuallyUploadsTheDeletion() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadDeletion(sharingGroupId: sharingGroupId)
    }
    
    func testThatTwoUploadDeletionsOfTheSameFileWork() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)

        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)

        getUploads(sharingGroupId: sharingGroupId, expectedFiles: [
            (fileUUID: fileUUID, fileSize: nil)
        ]) { fileInfo in
            XCTAssert(fileInfo.deleted)
        }
    }
    
    // TODO: *0* Do an upload deletion, then a second upload deletion with the same file-- make sure the 2nd one fails.
    
    func testThatActualDeletionInDebugWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)

        var fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupId: sharingGroupId)
        fileToDelete.actualDeletion = true
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: []) { fileInfo in
            XCTAssert(fileInfo.fileUUID != fileUUID)
        }
    }
    
    func testDeleteAllServerFiles() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }

        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)
        
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
    
        sharingGroups.forEach { sharingGroup in
            if let sharingGroupId = sharingGroup.sharingGroupId {
                removeAllServerFilesInFileIndex(sharingGroupId: sharingGroupId)
                getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: []) { fileInfo in
                    XCTFail()
                }
            }
            else {
                XCTFail()
            }
        }
    }
}
