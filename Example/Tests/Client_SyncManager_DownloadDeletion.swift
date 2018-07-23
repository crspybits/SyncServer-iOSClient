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
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)
        
        // Now, see if `SyncManager.session.start` finds the download deletion...
        
        var calledShouldDoDeletions = false
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            let attr = group[0].attr
            
            XCTAssert(attr.fileUUID == file.fileUUID)
            XCTAssert(!calledShouldDoDeletions)
            calledShouldDoDeletions = true
        }
        
        let expectation2 = self.expectation(description: "start")
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(calledShouldDoDeletions)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }

    func testStartWithOneDownloadDeletion() {
        startWithOneDownloadDeletion()
    }

    func testStartWithTwoDownloadDeletions() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file1, _) = uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard let (file2, masterVersion) = uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the files.
        let currDeviceUUID = deviceUUID
        deviceUUID = Foundation.UUID()
        
        let fileToDelete1 = ServerAPI.FileToDelete(fileUUID: file1.fileUUID, fileVersion: file1.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete1, masterVersion: masterVersion)

        let fileToDelete2 = ServerAPI.FileToDelete(fileUUID: file2.fileUUID, fileVersion: file2.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete2, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)
        
        // Now, see if `SyncManager.session.start` finds the download deletions...
        
        deviceUUID = currDeviceUUID

        var numberDeletions = 0
        var firstDeletion = false
        var secondDeletion = false
        let expectation2 = self.expectation(description: "start")

        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            numberDeletions += 1
            
            let result1 = group.filter {$0.attr.fileUUID == file1.fileUUID}
            if result1.count == 1 {
                firstDeletion = true
            }

            let result2 = group.filter {$0.attr.fileUUID == file2.fileUUID}
            if result2.count == 1 {
                secondDeletion = true
            }
        }
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(numberDeletions == 2 && firstDeletion && secondDeletion)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testStartWithOneDownloadDeletionAndOneFileDownload() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file1, masterVersion) = uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file1.fileUUID, fileVersion: file1.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        let fileUUID2 = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file2) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)
        
        // Now, see if `SyncManager.session.start` finds the download  and deletion...
        
        var calledShouldDoDeletions = false
        var calledShouldSaveDownloads = false
        
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            downloadCount += 1
            XCTAssert(downloadCount <= 2)
            let attr = group[0].attr
            
            switch group[0].type {
            case .file:
                XCTAssert(attr.fileUUID == file2.fileUUID)
                XCTAssert(!calledShouldSaveDownloads)
                calledShouldSaveDownloads = true
                
            case .deletion:
                XCTAssert(attr.fileUUID == file1.fileUUID)
                XCTAssert(!calledShouldDoDeletions)
                calledShouldDoDeletions = true
                
            case .appMetaData:
                XCTFail()
            }
        }
        
        let expectation2 = self.expectation(description: "start")
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(calledShouldDoDeletions)
            XCTAssert(calledShouldSaveDownloads)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }

    func testDownloadDeletionWithKnownDeletedFile() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        startWithOneDownloadDeletion()
        
        // We now have an entry in the local directory which is known to be deleted.
        
        var calledShouldDoDeletions = false
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            calledShouldDoDeletions = true
        }
        
        let expectation = self.expectation(description: "start")

        syncServerEventOccurred = { event in
            XCTFail()
        }

        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(!calledShouldDoDeletions)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadDeletionWhereFileWasNotInDirectoryPreviously() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }

        uploadDeletionOfOneFileWithDoneUploads(sharingGroupId: sharingGroupId)
        
        var calledShouldDoDeletions = false
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            calledShouldDoDeletions = true
        }
        
        let expectation = self.expectation(description: "start")

        syncServerEventOccurred = { event in
            XCTFail()
        }
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(!calledShouldDoDeletions)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
}
