//
//  ServerAPI_MultiVersionFiles.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 1/11/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class ServerAPI_MultiVersionFiles: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest(actualDeletion:false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func uploadTextFileVersion(_ version:FileVersionInt, sharingGroupUUID: String) {
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        uploadFileVersion(version, fileURL: fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID)
    }

    // Uploading version 1 of file with nil app meta data doesn't reset app meta data.
    func testAppMetaDataNotChangedWithNilValue() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let mimeType:MimeType = .text
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        let appMetaData = AppMetaData(version: 0, contents: "foobar")
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        fileVersion += 1
        masterVersion += 1
        
        // Second upload-- nil appMetaData
        guard let file = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: nil, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        masterVersion += 1

        onlyDownloadFile(comparisonFileURL: fileURL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, appMetaData: appMetaData)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadTextFileVersion1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadTextFileVersion(1, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testThatUploadingNonConsecutiveFileVersionFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        masterVersion += 1
        
        // +1 works, but +2 should fail.
        fileVersion += 2
        
        uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true, fileVersion: fileVersion)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    @discardableResult
    func uploadDeleteFileVersion1(sharingGroupUUID: String) -> ServerAPI.File? {
        var result: ServerAPI.File?
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        masterVersion += 1
        fileVersion += 1
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
        result = file
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        masterVersion += 1
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        return result
    }
    
    // Upload deletion
    func testUploadDeleteFileVersion1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadDeleteFileVersion1(sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadAfterUploadDeleteOfVersion1Fails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let file:ServerAPI.File = uploadDeleteFileVersion1(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        uploadFile(fileURL:file.localURL, mimeType: file.mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: file.fileUUID, serverMasterVersion: masterVersion, expectError: true, fileVersion: file.fileVersion + FileVersionInt(1))
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }

    func testUploadAndDownloadTextFileVersion5Works() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadTextFileVersion(5, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadAndDownloadImageFileVersion2Works() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileName = "Cat"
        let fileExtension = "jpg"
        let mimeType:MimeType = .jpeg
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        uploadFileVersion(2, fileURL: fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadUndeletionVersion1Works() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let file:ServerAPI.File = uploadDeleteFileVersion1(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let file2 = uploadFile(fileURL:file.localURL, mimeType: file.mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: file.fileUUID, serverMasterVersion: masterVersion, fileVersion: file.fileVersion + FileVersionInt(1), undelete: true) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        onlyDownloadFile(comparisonFileURL: file2.localURL, file: file2, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: nil)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    // Upload to file version N, but don't do the last DoneUploads
    func uploadToFileVersion(_ version: FileVersionInt, masterVersion: MasterVersionInt, sharingGroupUUID: String) -> (ServerAPI.File, masterVersion: MasterVersionInt)? {
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        var fileVersion:FileVersionInt = 0
        let mimeType:MimeType = .text
        var masterVersion = masterVersion
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
    
        var resultFile:ServerAPI.File = file
        
        while fileVersion < version {
            doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
            
            masterVersion += 1
            fileVersion += 1
            
            guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
                XCTFail()
                return nil
            }
            
            resultFile = file
        }
        
        return (resultFile, masterVersion)
    }
    
    /* We now have several different types of items that can be pending for DoneUploads--
        a) file upload (version 0)
        b) upload deletion
        c) upload undeletion
        d) file upload (version > 0)
     
        Let's try having one of each of these and then do a DoneUploads.
    */
    func testDifferentTypesOfUploadAtSameTime() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // This is preparation: Getting ready for staging the items to be pending for the DoneUploads test.
        guard let file1:ServerAPI.File = uploadDeleteFileVersion1(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID3 = UUID().uuidString
        let fileURL3 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard var masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let file3 = uploadFile(fileURL:fileURL3, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID3, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        // 1) The upload of file version N (Doesn't do the last DoneUploads).
        guard let (file4, updatedMasterVersion) = uploadToFileVersion(4, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        masterVersion = updatedMasterVersion
        
        // 2) Stage an upload undeletion
        guard let file1b = uploadFile(fileURL:file1.localURL, mimeType: file1.mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: file1.fileUUID, serverMasterVersion: masterVersion, fileVersion: file1.fileVersion + FileVersionInt(1), undelete: true) else {
            XCTFail()
            return
        }
        
        // 3) The file upload
        let fileUUID2 = UUID().uuidString
        let fileURL2 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file2 = uploadFile(fileURL:fileURL2, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        
        // 4) The upload deletion
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file3.fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        // Finally: This tests DoneUploads with these four different types of pending uploads.
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 4)
        
        // Test to make sure we got what we wanted.
        // A) Download the undeleted file.
        onlyDownloadFile(comparisonFileURL: file1.localURL, file: file1b, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: nil)

        // B) Download the uploaded file.
        onlyDownloadFile(comparisonFileURL: file2.localURL, file: file2, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: nil)
        
        // C) Make sure the deleted file was deleted.
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let result = fileIndex.filter({$0.fileUUID == file3.fileUUID})
        guard result.count == 1, result[0].deleted else {
            XCTFail()
            return
        }

        // D) Download the uploaded file
        onlyDownloadFile(comparisonFileURL: file4.localURL, file: file4, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: nil)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
}
