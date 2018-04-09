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
        uploadFileVersion(version, fileURL: fileURL, mimeType: .text)
    }
    
    func uploadFileVersion(_ version:FileVersionInt, fileURL: URL, mimeType:MimeType) {
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
        
            guard let (fileSize, file) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
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
    
        guard let fileIndex:[FileInfo] = getFileIndex() else {
            XCTFail()
            return
        }
        
        let result = fileIndex.filter({$0.fileUUID == fileUUID})
        guard result.count == 1 else {
            XCTFail()
            return
        }

        XCTAssert(result[0].fileVersion == fileVersion)
        XCTAssert(result[0].deviceUUID == file.deviceUUID)
        
        if let resultMimeTypeString = result[0].mimeType {
            let resultMimeType = MimeType(rawValue: resultMimeTypeString)
            XCTAssert(resultMimeType == file.mimeType)
        }
        else {
            XCTFail()
        }
        
        onlyDownloadFile(comparisonFileURL: fileURL, file: file, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize)
    }

    // Uploading version 1 of file with nil app meta data doesn't reset app meta data.
    func testAppMetaDataNotChangedWithNilValue() {
        var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let mimeType:MimeType = .text
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        let appMetaData = AppMetaData(version: 0, contents: "foobar")
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        fileVersion += 1
        masterVersion += 1
        
        // Second upload-- nil appMetaData
        guard let (fileSize, file) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: nil, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1

        onlyDownloadFile(comparisonFileURL: fileURL, file: file, masterVersion: masterVersion, appMetaData: appMetaData, fileSize: fileSize)
    }
    
    func testUploadTextFileVersion1() {
        uploadTextFileVersion(1)
    }
    
    func testThatUploadingNonConsecutiveFileVersionFails() {
        var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1
        
        // +1 works, but +2 should fail.
        fileVersion += 2
        
        uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true, fileVersion: fileVersion)
    }
    
    @discardableResult
    func uploadDeleteFileVersion1() -> ServerAPI.File? {
        var result: ServerAPI.File?
        
        var masterVersion = getMasterVersion()
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        masterVersion += 1
        fileVersion += 1
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
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
        let mimeType:MimeType = .jpeg
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
    
    // Upload to file version N, but don't do the last DoneUploads
    func uploadToFileVersion(_ version: FileVersionInt, masterVersion: MasterVersionInt) -> (Int64, ServerAPI.File, masterVersion: MasterVersionInt)? {
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        var fileVersion:FileVersionInt = 0
        let mimeType:MimeType = .text
        var masterVersion = masterVersion
        
        guard let (fileSize, file) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
            XCTFail()
            return nil
        }
    
        var resultFileSize:Int64 = fileSize
        var resultFile:ServerAPI.File = file
        
        while fileVersion < version {
            doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
            
            masterVersion += 1
            fileVersion += 1
            
            guard let (fileSize, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion) else {
                XCTFail()
                return nil
            }
            
            resultFileSize = fileSize
            resultFile = file
        }
        
        return (resultFileSize, resultFile, masterVersion)
    }
    
    /* We now have several different types of items that can be pending for DoneUploads--
        a) file upload (version 0)
        b) upload deletion
        c) upload undeletion
        d) file upload (version > 0)
     
        Let's try having one of each of these and then do a DoneUploads.
    */
    func testDifferentTypesOfUploadAtSameTime() {
        // This is preparation: Getting ready for staging the items to be pending for the DoneUploads test.
        guard let file1:ServerAPI.File = uploadDeleteFileVersion1() else {
            XCTFail()
            return
        }
        
        let fileUUID3 = UUID().uuidString
        let fileURL3 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        var masterVersion = getMasterVersion()
        guard let (_, file3) = uploadFile(fileURL:fileURL3, mimeType: .text, fileUUID: fileUUID3, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        // 1) The upload of file version N (Doesn't do the last DoneUploads).
        guard let (fileSize4, file4, updatedMasterVersion) = uploadToFileVersion(4, masterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        masterVersion = updatedMasterVersion
        
        // 2) Stage an upload undeletion
        guard let (fileSize1, file1b) = uploadFile(fileURL:file1.localURL, mimeType: file1.mimeType, fileUUID: file1.fileUUID, serverMasterVersion: masterVersion, fileVersion: file1.fileVersion + FileVersionInt(1), undelete: true) else {
            XCTFail()
            return
        }
        
        // 3) The file upload
        let fileUUID2 = UUID().uuidString
        let fileURL2 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (fileSize2, file2) = uploadFile(fileURL:fileURL2, mimeType: .text, fileUUID: fileUUID2, serverMasterVersion: masterVersion, fileVersion: 0) else {
            XCTFail()
            return
        }
        
        // 4) The upload deletion
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file3.fileUUID, fileVersion: 0)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        // Finally: This tests DoneUploads with these four different types of pending uploads.
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 4)
        
        // Test to make sure we got what we wanted.
        // A) Download the undeleted file.
        onlyDownloadFile(comparisonFileURL: file1.localURL, file: file1b, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize1)

        // B) Download the uploaded file.
        onlyDownloadFile(comparisonFileURL: file2.localURL, file: file2, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize2)
        
        // C) Make sure the deleted file was deleted.
        guard let fileIndex = getFileIndex() else {
            XCTFail()
            return
        }
        
        let result = fileIndex.filter({$0.fileUUID == file3.fileUUID})
        guard result.count == 1, result[0].deleted else {
            XCTFail()
            return
        }

        // D) Download the uploaded file
        onlyDownloadFile(comparisonFileURL: file4.localURL, file: file4, masterVersion: masterVersion + 1, appMetaData: nil, fileSize: fileSize4)
    }
}
