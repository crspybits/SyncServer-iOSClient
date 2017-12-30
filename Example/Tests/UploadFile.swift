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
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUploadTextFile() {
        let masterVersion = getMasterVersion()
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: "text/plain", serverMasterVersion: masterVersion)
    }
    
    func testUploadJPEGFile() {
        let masterVersion = getMasterVersion()
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "Cat", withExtension: "jpg")!
        _ = uploadFile(fileURL:fileURL, mimeType: "image/jpeg", serverMasterVersion: masterVersion)
    }
    
    func testUploadTextFileWithNoAuthFails() {
        ServerNetworking.session.authenticationDelegate = nil
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: "text/plain", expectError: true)
    }
    
    // This should not fail because the second attempt doesn't add a second upload deletion-- the second attempt is to allow for recovery/retries.
    func testUploadTwoFilesWithSameUUIDFails() {
        let masterVersion = getMasterVersion()
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        _ = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion)
        
        _ = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion)
    }
    
    func testParallelUploadsWork() {
        let masterVersion = getMasterVersion()

        let expectation1 = self.expectation(description: "upload1")
        let expectation2 = self.expectation(description: "upload2")
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        Log.special("fileUUID1= \(fileUUID1); fileUUID2= \(fileUUID2)")
        
        uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID:fileUUID1, serverMasterVersion: masterVersion, withExpectation:expectation1)
        
        uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID:fileUUID2, serverMasterVersion: masterVersion, withExpectation:expectation2)

        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // The creation date of the file is established by the server, and should fall between the server date/time before the upload and the server date/time after the upload.
    func testThatCreationDateOfFileIsReasonable() {
        let masterVersion = getMasterVersion()
        
        guard let health1 = healthCheck(), let serverDateTimeBefore = health1.currentServerDateTime else {
            XCTFail()
            return
        }
        
        let uploadFileUUID = UUID().uuidString
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, mimeType: "text/plain", cloudFolderName: cloudFolderName, deviceUUID: deviceUUID.uuidString, appMetaData: nil, fileVersion: 0)
        
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
            case .success(sizeInBytes: _, creationDate: let creationDate, updateDate: let updateDate):
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
}
