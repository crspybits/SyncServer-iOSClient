//
//  Client_SyncManager_FileUpload.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/3/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_FileUpload: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        SyncServer.session.eventsDesired = .defaults
        super.tearDown()
    }

    func uploadASingleFile(copy:Bool, sharingGroupUUID: String, fileURL:SMRelativeLocalURL? = nil, mimeType: MimeType = .text) {
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileURL: fileURL, mimeType: mimeType, uploadCopy: copy) else {
            XCTFail()
            return
        }
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [attr.fileUUID])
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: attr.fileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testThatUploadingASingleImmutableTextFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadASingleFile(copy:false, sharingGroupUUID: sharingGroupUUID)
        
        assertUploadTrackersAreReset()
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatUploadingASingleImmutableURLFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let url = SMRelativeLocalURL(withRelativePath: "example.url", toBaseURLType: .mainBundle) else {
            XCTFail()
            return
        }
        
        uploadASingleFile(copy:false, sharingGroupUUID: sharingGroupUUID, fileURL: url, mimeType: .url)
        
        assertUploadTrackersAreReset()
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatUploadingASingleCopyFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadASingleFile(copy:true, sharingGroupUUID: sharingGroupUUID)
        
        assertUploadTrackersAreReset()
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func uploadTwoSeparateFilesWorks(copy:Bool, sharingGroupUUID: String) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        
        var uploadsCompleted = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 2)
                XCTAssert(uploadsCompleted == 2)
                expectation2.fulfill()
                
            case .singleFileUploadComplete(_):
                uploadsCompleted += 1
                
            default:
                XCTFail()
            }
        }
        
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url, withAttributes: attr1)
            try! SyncServer.session.uploadCopy(localFile: url, withAttributes: attr2)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID1,
            fileUUID2
        ])
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url as URL, file: file1, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url as URL, file: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testThatUploadingTwoSeparateImmutableFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadTwoSeparateFilesWorks(copy:false, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatUploadingTwoSeparateCopyFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadTwoSeparateFilesWorks(copy:true, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }

    // TODO: *2* file will have deleted flag set in local Directory.
    // This is commented out until we do multi-version files.
/*
    func testThatUploadOfPreviouslyDeletedFileFails() {
    }
*/

    func addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy:Bool, sharingGroupUUID: String) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        let expectation3 = self.expectation(description: "test3")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                // Only a single file was uploaded.
                XCTAssert(number == 1)
                expectation2.fulfill()
            
            case .singleFileUploadComplete(_):
                expectation3.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url1, withAttributes: attr)
            try! SyncServer.session.uploadCopy(localFile: url2, withAttributes: attr)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url1, withAttributes: attr)
            try! SyncServer.session.uploadImmutable(localFile: url2, withAttributes: attr)
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [fileUUID])
        
        // Download the file and make sure it corresponds to url2
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testThatAddingSameImmutableFileToUploadQueueTwiceBeforeSyncReplaces() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: false, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatAddingSameCopyFileToUploadQueueTwiceBeforeSyncReplaces() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: true, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func changingTheMimeTypeOnSecondUploadFails(copy: Bool, sharingGroupUUID: String) {
       let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        
        let attr1 = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        // Different mime type for second upload attempt.
        let attr2 = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .jpeg)
        
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url1, withAttributes: attr1)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url1, withAttributes: attr1)
        }
        
        var gotError = false
        do {
            if copy {
                try SyncServer.session.uploadCopy(localFile: url2, withAttributes: attr2)
            }
            else {
                try SyncServer.session.uploadImmutable(localFile: url2, withAttributes: attr2)
            }
        } catch {
            gotError = true
        }
        
        XCTAssert(gotError)
    }
    
    func testThatChangingTheMimeTypeOnSecondUploadImmutableFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        changingTheMimeTypeOnSecondUploadFails(copy: false, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testThatChangingTheMimeTypeOnSecondUploadCopyFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        changingTheMimeTypeOnSecondUploadFails(copy: true, sharingGroupUUID: sharingGroupUUID)
    }

    func syncAferCompleteUploadWorks(copy: Bool, sharingGroupUUID: String) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        let syncDone1 = self.expectation(description: "test1")
        let syncDone2 = self.expectation(description: "test2")

        let expectation3 = self.expectation(description: "test3")
        let expectation4 = self.expectation(description: "test4")
        
        var count = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                count += 1
                switch count {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation3.fulfill()
                
            case .singleFileUploadComplete(attr: let attr):
                XCTAssert(attr.fileUUID == fileUUID, "FileUUID was: \(fileUUID)")
                XCTAssert(attr.mimeType == .text)
                expectation4.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url, withAttributes: attr)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [fileUUID])
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testSyncAferCompleteUploadImmutableWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        syncAferCompleteUploadWorks(copy: false, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testSyncAferCompleteUploadCopyWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        syncAferCompleteUploadWorks(copy: true, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: Bool, sharingGroupUUID: String) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)

        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID2 = UUID().uuidString
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        let expectSyncDone1 = self.expectation(description: "test1")
        let expectSyncDone2 = self.expectation(description: "test2")
        let expectFileUploadsCompleted1 = self.expectation(description: "test3")
        let expectFileUploadsCompleted2 = self.expectation(description: "test4")
        let expectSingleUploadComplete1 = self.expectation(description: "test5")
        let expectSingleUploadComplete2 = self.expectation(description: "test6")

        var syncDoneCount = 0
        var fileUploadsCompletedCount = 0
        var singleUploadCompleteCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    expectSyncDone1.fulfill()
                    
                case 2:
                    expectSyncDone2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                fileUploadsCompletedCount += 1
                XCTAssert(number == 1)
                
                switch fileUploadsCompletedCount {
                case 1:
                    expectFileUploadsCompleted1.fulfill()
                    
                case 2:
                    expectFileUploadsCompleted2.fulfill()
                    
                default:
                    XCTFail()
                }
            
            case .singleFileUploadComplete(_):
                singleUploadCompleteCount += 1
                switch singleUploadCompleteCount {
                case 1:
                    expectSingleUploadComplete1.fulfill()
                    
                case 2:
                    expectSingleUploadComplete2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            default:
                XCTFail()
            }
        }
        
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url1, withAttributes: attr1)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url1, withAttributes: attr1)
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        if copy {
            try! SyncServer.session.uploadCopy(localFile: url2, withAttributes: attr2)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url2, withAttributes: attr2)
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID1,
            fileUUID2
        ])
        
        // Download and check the files
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url1 as URL, file: file1, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testUploadImmutableOfDifferentFilesAcrossDifferentSyncsWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: false, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testUploadCopyOfDifferentFilesAcrossDifferentSyncsWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: true, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func creationDateOfFileIsCorrect(copy: Bool, sharingGroupUUID: String) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        // Queue's the file for upload.
        if copy {
            try! SyncServer.session.uploadCopy(localFile: url, withAttributes: attr)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        }
        
        // Get the server date/time *after* the queuing.
        guard let health1 = healthCheck(), let serverDateTimeBefore = health1.currentServerDateTime else {
            XCTFail()
            return
        }
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        var syncAttr:SyncAttributes?
        
        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]

        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
            
            case .singleFileUploadComplete(attr: let attr):
                syncAttr = attr
                expectation2.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let health2 = healthCheck(), let serverDateTimeAfter = health2.currentServerDateTime else {
            XCTFail()
            return
        }
        
        if let creationDate = syncAttr?.creationDate, let updateDate = syncAttr?.updateDate, syncAttr != nil {
            XCTAssert(serverDateTimeBefore <= creationDate && creationDate <= serverDateTimeAfter)
            XCTAssert(serverDateTimeBefore <= updateDate && creationDate <= serverDateTimeAfter)
        }
        else {
            XCTFail()
        }
    }
    
    // The purpose of this test is to make sure that, despite the fact that we queue the file for upload, that the file creation date/time occurs *after* we start the sync operation.
    func testThatCreationDateOfImmutableFileIsCorrect() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        creationDateOfFileIsCorrect(copy: false, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatCreationDateOfCopyFileIsCorrect() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        creationDateOfFileIsCorrect(copy: true, sharingGroupUUID: sharingGroupUUID)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    // TODO: *3* Test of upload file1, sync, upload file1, sync-- uploads both files.
    //      Needs to wait until we have version support.
}
