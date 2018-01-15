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
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func uploadTextFileVersion(_ version:FileVersionInt) {
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        uploadFileVersion(version, fileURL: fileURL, mimeType: "text/plain")
    }
    
    func uploadFileVersion(_ version:FileVersionInt, fileURL: URL, mimeType:String) {
       var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
    
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
    
        var resultFileSize:Int64?
        var resultFile:ServerAPI.File?
        
        while fileVersion < version {
            masterVersion += 1
            fileVersion += 1
        
            guard let (fileSize, file) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
                XCTFail()
                return
            }
            
            resultFileSize = fileSize
            resultFile = file
            
            doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        }
        
        guard let file = resultFile, let fileSize = resultFileSize else {
            XCTFail()
            return
        }
    
        let fileIndex:[FileInfo] = getFileIndex()
        let result = fileIndex.filter({$0.fileUUID == fileUUID})
        guard result.count == 1 else {
            XCTFail()
            return
        }

        XCTAssert(result[0].fileVersion == fileVersion)
        XCTAssert(result[0].appMetaData == file.appMetaData)
        XCTAssert(result[0].cloudFolderName == file.cloudFolderName)
        XCTAssert(result[0].deviceUUID == file.deviceUUID)
        XCTAssert(result[0].mimeType == file.mimeType)
    
        onlyDownloadFile(comparisonFileURL: fileURL, file: file, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize)
    }
    
    func testUploadTextFileVersion1() {
        uploadTextFileVersion(1)
    }
    
    func testThatUploadingNonConsecutiveFileVersionFails() {
        var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1
        
        // +1 works, but +2 should fail.
        fileVersion += 2
        
        uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true, fileVersion: fileVersion)
    }
    
    @discardableResult
    func uploadDeleteFileVersion1() -> ServerAPI.File? {
        var result: ServerAPI.File?
        
        var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1
        fileVersion += 1
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
        result = file
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        return result
    }
    
    // Upload deletion
    func testUploadDeleteFileVersion1() {
        uploadDeleteFileVersion1()
    }
    
    func testUploadAfterUploadDeleteOfVersion1Fails() {
        guard let file:ServerAPI.File = uploadDeleteFileVersion1() else {
            XCTFail()
            return
        }
        
        let masterVersion = getMasterVersion()
        uploadFile(fileURL:file.localURL, mimeType: file.mimeType, fileUUID: file.fileUUID, serverMasterVersion: masterVersion, expectError: true, fileVersion: file.fileVersion + FileVersionInt(1))
    }

    func testUploadAndDownloadTextFileVersion5Works() {
        uploadTextFileVersion(5)
    }
    
    func testUploadAndDownloadImageFileVersion2Works() {
        let fileName = "Cat"
        let fileExtension = "jpg"
        let mimeType = "image/jpeg"
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        uploadFileVersion(2, fileURL: fileURL, mimeType: mimeType)
    }
    
    func testUploadUndeletionVersion1Works() {
        guard let file:ServerAPI.File = uploadDeleteFileVersion1() else {
            XCTFail()
            return
        }
        
        let masterVersion = getMasterVersion()
        guard let (fileSize, file2) = uploadFile(fileURL:file.localURL, mimeType: file.mimeType, fileUUID: file.fileUUID, serverMasterVersion: masterVersion, fileVersion: file.fileVersion + FileVersionInt(1), undelete: true) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)

        onlyDownloadFile(comparisonFileURL: file2.localURL, file: file2, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize)
    }
    
    /* We now have several different types of items that can be pending for DoneUploads--
        a) file upload
        b) upload deletion
        c) upload undeletion
     
        Let's try having one of each of these and then do a DoneUploads.
    */
    func testUploadUndeletionDeletionUploadAtSameTime() {
        guard let file1:ServerAPI.File = uploadDeleteFileVersion1() else {
            XCTFail()
            return
        }
        
        let fileUUID3 = UUID().uuidString
        let fileURL3 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        var masterVersion = getMasterVersion()
        guard let (_, file3) = uploadFile(fileURL:fileURL3, mimeType: "text/plain", fileUUID: fileUUID3, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        // 1) The upload undeletion
        guard let (fileSize1, file1b) = uploadFile(fileURL:file1.localURL, mimeType: file1.mimeType, fileUUID: file1.fileUUID, serverMasterVersion: masterVersion, fileVersion: file1.fileVersion + FileVersionInt(1), undelete: true) else {
            XCTFail()
            return
        }
        
        // 2) The file upload
        let fileUUID2 = UUID().uuidString
        let fileURL2 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (fileSize2, file2) = uploadFile(fileURL:fileURL2, mimeType: "text/plain", fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        
        // 3) The upload deletion
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file3.fileUUID, fileVersion: 0)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)

        // Finally, do the DoneUploads
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 3)
        
        // Test to make sure we got what we wanted.
        // 1) Download the undeleted file.
        onlyDownloadFile(comparisonFileURL: file1.localURL, file: file1b, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize1)

        // 2) Download the uploaded file.
        onlyDownloadFile(comparisonFileURL: file2.localURL, file: file2, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize2)
        
        // 3) Make sure the deleted file was deleted.
        let fileIndex:[FileInfo] = getFileIndex()
        let result = fileIndex.filter({$0.fileUUID == file3.fileUUID})
        guard result.count == 1, result[0].deleted else {
            XCTFail()
            return
        }
    }
}