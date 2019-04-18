//
//  UploadFile.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/4/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerAPI_UploadFile: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUploadTextFile() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
    }
    
    func testUploadJPEGFile() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "Cat", withExtension: "jpg")!
        _ = uploadFile(fileURL:fileURL, mimeType: .jpeg, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
    }
    
    func testUploadURLFile() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let url = Bundle.main.url(forResource: "example", withExtension: "url") else {
            XCTFail()
            return
        }
        
        _ = uploadFile(fileURL:url, mimeType: .url, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
    }
    
    func testUploadTextFileWithNoAuthFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        ServerNetworking.session.delegate = nil
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, expectError: true)
    }
    
    // This should not fail because the second attempt doesn't add a second upload deletion-- the second attempt is to allow for recovery/retries.
    func testUploadTwoFilesWithSameUUIDFails() {
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
        
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion)
        
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion)
    }
    
    func testParallelUploadsWork() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let expectation1 = self.expectation(description: "upload1")
        let expectation2 = self.expectation(description: "upload2")
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        Log.special("fileUUID1= \(fileUUID1); fileUUID2= \(fileUUID2)")
        
        uploadFile(fileName: "UploadMe", fileExtension: "txt", sharingGroupUUID: sharingGroupUUID, mimeType: .text, fileUUID:fileUUID1, serverMasterVersion: masterVersion, withExpectation:expectation1)
        
        uploadFile(fileName: "UploadMe", fileExtension: "txt", sharingGroupUUID: sharingGroupUUID, mimeType: .text, fileUUID:fileUUID2, serverMasterVersion: masterVersion, withExpectation:expectation2)

        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // The creation date of the file is established by the server, and should fall between the server date/time before the upload and the server date/time after the upload.
    func testThatCreationDateOfFileIsReasonable() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let health1 = healthCheck(), let serverDateTimeBefore = health1.currentServerDateTime else {
            XCTFail()
            return
        }
        
        let uploadFileUUID = UUID().uuidString
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let signIn = SignInManager.session.currentSignIn,
            signIn.userType == .owning,
            let cloudStorageType = signIn.cloudStorageType else {
            XCTFail()
            return
        }
        
        guard let checkSum = Hashing.hashOf(url: fileURL, for: cloudStorageType) else {
            XCTFail()
            return
        }
        
        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: .text, deviceUUID: deviceUUID.uuidString, appMetaData: nil, fileVersion: 0, checkSum: checkSum)
        
        var uploadResult:ServerAPI.UploadFileResult?
        
        let exp = self.expectation(description: "exp")
        
        ServerAPI.session.uploadFile(file: file, serverMasterVersion: masterVersion) { uploadFileResult, error in
        
            XCTAssert(error == nil)
            uploadResult = uploadFileResult
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)

        guard let health2 = healthCheck(), let serverDateTimeAfter = health2.currentServerDateTime else {
            XCTFail()
            return
        }
        
        if uploadResult != nil {
            switch uploadResult! {
            case .success(creationDate: let creationDate, updateDate: let updateDate):
                XCTAssert(serverDateTimeBefore <= creationDate && creationDate <= serverDateTimeAfter)
                XCTAssert(serverDateTimeBefore <= updateDate && updateDate <= serverDateTimeAfter)
            default:
                XCTFail()
            }
        }
        else {
            XCTFail()
        }
    }

    // Upload a file with groupUUID, make sure you get it with a file index.
    func testUploadWithFileGroupUUID() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        let fileGroupUUID = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let result = fileIndex.filter {$0.fileUUID == file.fileUUID}
        guard result.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(result[0].fileGroupUUID == fileGroupUUID)
    }
    
    func testThatUploadingWithIncorrectCheckSumFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        let fileGroupUUID = UUID().uuidString
        
        // Some random incorrect checksum
        let incorrectCheckSum = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion, expectError: true, fileGroupUUID: fileGroupUUID, useCheckSum: incorrectCheckSum)
    }
}
