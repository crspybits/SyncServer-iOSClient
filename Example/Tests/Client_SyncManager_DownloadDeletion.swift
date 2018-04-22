//
//  Client_SyncManager_DownloadDeletion.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/27/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class Client_SyncManager_DownloadDeletion: TestCase {
    
    override func setUp() {
        super.setUp()
        
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func startWithOneDownloadDeletion() {
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // Now, see if `SyncManager.session.start` finds the download deletion...
        
        var calledShouldDoDeletions = false
        
        shouldDoDeletions = { (downloadDeletions:[SyncAttributes]) in
            XCTAssert(downloadDeletions.count == 1)
            XCTAssert(downloadDeletions[0].fileUUID == file.fileUUID)
            XCTAssert(!calledShouldDoDeletions)
            calledShouldDoDeletions = true
        }
        
        let expectation2 = self.expectation(description: "start")
        
        SyncManager.session.start { (error) in
            XCTAssert(calledShouldDoDeletions)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }

    func testStartWithOneDownloadDeletion() {
        startWithOneDownloadDeletion()
    }

    func testStartWithTwoDownloadDeletions() {
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file1, _) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        guard let (file2, masterVersion) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the files.
        let currDeviceUUID = deviceUUID
        deviceUUID = Foundation.UUID()
        
        let fileToDelete1 = ServerAPI.FileToDelete(fileUUID: file1.fileUUID, fileVersion: file1.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete1, masterVersion: masterVersion)

        let fileToDelete2 = ServerAPI.FileToDelete(fileUUID: file2.fileUUID, fileVersion: file2.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete2, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        // Now, see if `SyncManager.session.start` finds the download deletions...
        
        deviceUUID = currDeviceUUID

        var calledShouldDoDeletions = false
        
        shouldDoDeletions = { (downloadDeletions:[SyncAttributes]) in
            XCTAssert(downloadDeletions.count == 2)
            
            let result1 = downloadDeletions.filter {$0.fileUUID == file1.fileUUID}
            XCTAssert(result1.count == 1)

            let result2 = downloadDeletions.filter {$0.fileUUID == file2.fileUUID}
            XCTAssert(result2.count == 1)
            
            calledShouldDoDeletions = true
        }
        
        let expectation2 = self.expectation(description: "start")
        
        SyncManager.session.start { (error) in
            XCTAssert(calledShouldDoDeletions)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testStartWithOneDownloadDeletionAndOneFileDownload() {
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file1, masterVersion) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file1.fileUUID, fileVersion: file1.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        let fileUUID2 = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file2) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        // Now, see if `SyncManager.session.start` finds the download  and deletion...
        
        var calledShouldDoDeletions = false
        var calledShouldSaveDownloads = false
        
        shouldDoDeletions = { (downloadDeletions:[SyncAttributes]) in
            XCTAssert(downloadDeletions.count == 1)
            XCTAssert(downloadDeletions[0].fileUUID == file1.fileUUID)
            calledShouldDoDeletions = true
        }
        
        var downloadCount = 0
        
        syncServerContentGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                let attr = group[0].attr
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                
                XCTAssert(attr.fileUUID == file2.fileUUID)
                XCTAssert(!calledShouldSaveDownloads)
                calledShouldSaveDownloads = true
            }
            else {
                XCTFail()
            }
        }
        
        let expectation2 = self.expectation(description: "start")
        
        SyncManager.session.start { (error) in
            XCTAssert(calledShouldDoDeletions)
            XCTAssert(calledShouldSaveDownloads)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }

    func testDownloadDeletionWithKnownDeletedFile() {
        startWithOneDownloadDeletion()
        
        // We now have an entry in the local directory which is known to be deleted.
        
        var calledShouldDoDeletions = false
        
        shouldDoDeletions = { (downloadDeletions:[SyncAttributes]) in            
            calledShouldDoDeletions = true
        }
        
        let expectation = self.expectation(description: "start")

        syncServerEventOccurred = { event in
            XCTFail()
        }

        SyncManager.session.start { (error) in
            XCTAssert(!calledShouldDoDeletions)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadDeletionWhereFileWasNotInDirectoryPreviously() {
        uploadDeletionOfOneFileWithDoneUploads()
        
        var calledShouldDoDeletions = false
        
        shouldDoDeletions = { (downloadDeletions:[SyncAttributes]) in            
            calledShouldDoDeletions = true
        }
        
        let expectation = self.expectation(description: "start")

        syncServerEventOccurred = { event in
            XCTFail()
        }
        
        SyncManager.session.start { (error) in
            XCTAssert(!calledShouldDoDeletions)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
}
