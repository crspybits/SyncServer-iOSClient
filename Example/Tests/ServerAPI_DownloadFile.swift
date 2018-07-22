//
//  ServerAPI_DownloadFile.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SyncServer_Shared

class ServerAPI_DownloadFile: TestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDownloadTextFile() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        uploadAndDownloadTextFile(sharingGroupId: sharingGroupId)
    }
    
    func testDownloadTextFileWithAppMetaData() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        let appMetaData = AppMetaData(version: 0, contents: "foobar was here")
        uploadAndDownloadTextFile(sharingGroupId: sharingGroupId, appMetaData: appMetaData)
    }
    
    // TODO: These downloads should really be with *different* files-- similar size would be good, but different files.
    func testThatParallelDownloadsWork() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "Cat", withExtension: "jpg")!
        let (_, file1) = uploadFile(fileURL:fileURL, mimeType: .jpeg, sharingGroupId: sharingGroupId, serverMasterVersion: masterVersion)!
        let (_, file2) = uploadFile(fileURL:fileURL, mimeType: .jpeg, sharingGroupId: sharingGroupId, serverMasterVersion: masterVersion)!
        
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)

        let expectation1 = self.expectation(description: "downloadFile1")
        let expectation2 = self.expectation(description: "downloadFile2")
        
        let fileNamingObj1 = FilenamingWithAppMetaDataVersion(fileUUID: file1.fileUUID, fileVersion: file1.fileVersion, appMetaDataVersion: nil)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj1, serverMasterVersion: masterVersion + 1, sharingGroupId: sharingGroupId) { (result, error) in
        
            XCTAssert(error == nil)
            XCTAssert(result != nil)
            
            if case .success(let downloadedFile) = result! {
                XCTAssert(FilesMisc.compareFiles(file1: fileURL, file2: downloadedFile.url as URL))
            }
            else {
                XCTFail()
            }
            
            expectation1.fulfill()
        }
        
        let fileNamingObj2 = FilenamingWithAppMetaDataVersion(fileUUID: file2.fileUUID, fileVersion: file2.fileVersion, appMetaDataVersion: nil)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj2, serverMasterVersion: masterVersion + 1, sharingGroupId: sharingGroupId) { (result, error) in
        
            XCTAssert(error == nil)
            XCTAssert(result != nil)
            
            if case .success(let downloadedFile) = result! {
                XCTAssert(FilesMisc.compareFiles(file1: fileURL, file2: downloadedFile.url as URL))
            }
            else {
                XCTFail()
            }
            
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 120.0, handler: nil)
    }
    
    // TODO: *1* Also try parallel downloads from different (simulated) deviceUUID's.
}
