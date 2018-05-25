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

        resetFileMetaData()
    }
    
    override func tearDown() {
        SyncServer.session.eventsDesired = .defaults
        super.tearDown()
    }

    func uploadASingleFile(copy:Bool) {
        guard let (url, attr) = uploadSingleFileUsingSync(uploadCopy: copy) else {
            XCTFail()
            return
        }
        
        getFileIndex(expectedFiles: [(fileUUID: attr.fileUUID, fileSize: nil)])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: attr.fileUUID, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion)
    }
    
    func testThatUploadingASingleImmutableFileWorks() {
        uploadASingleFile(copy:false)
    }
    
    func testThatUploadingASingleCopyFileWorks() {
        uploadASingleFile(copy:true)
    }
    
    func uploadTwoSeparateFilesWorks(copy:Bool) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, mimeType: .text)

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
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(expectedFiles: [
            (fileUUID: fileUUID1, fileSize: nil),
            (fileUUID: fileUUID2, fileSize: nil)
        ])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file1, masterVersion: masterVersion)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file2, masterVersion: masterVersion)
    }
    
    func testThatUploadingTwoSeparateImmutableFilesWorks() {
        uploadTwoSeparateFilesWorks(copy:false)
    }
    
    func testThatUploadingTwoSeparateCopyFilesWorks() {
        uploadTwoSeparateFilesWorks(copy:true)
    }

    // TODO: *2* file will have deleted flag set in local Directory.
    // This is commented out until we do multi-version files.
/*
    func testThatUploadOfPreviouslyDeletedFileFails() {
    }
*/

    func addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy:Bool) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
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
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(expectedFiles: [(fileUUID: fileUUID, fileSize: nil)])
        
        // Download the file and make sure it corresponds to url2
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file, masterVersion: masterVersion)
    }
    
    func testThatAddingSameImmutableFileToUploadQueueTwiceBeforeSyncReplaces() {
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: false)
    }
    
    func testThatAddingSameCopyFileToUploadQueueTwiceBeforeSyncReplaces() {
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: true)
    }
    
    func changingTheMimeTypeOnSecondUploadFails(copy: Bool) {
       let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        
        let attr1 = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
        // Different mime type for second upload attempt.
        let attr2 = SyncAttributes(fileUUID: fileUUID, mimeType: .jpeg)
        
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
        changingTheMimeTypeOnSecondUploadFails(copy: false)
    }
    
    func testThatChangingTheMimeTypeOnSecondUploadCopyFails() {
        changingTheMimeTypeOnSecondUploadFails(copy: true)
    }

    func syncAferCompleteUploadWorks(copy: Bool) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
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
        
        SyncServer.session.sync()
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(expectedFiles: [(fileUUID: fileUUID, fileSize: nil)])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion)
    }
    
    func testSyncAferCompleteUploadImmutableWorks() {
        syncAferCompleteUploadWorks(copy: false)
    }
    
    func testSyncAferCompleteUploadCopyWorks() {
        syncAferCompleteUploadWorks(copy: true)
    }
    
    func uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: Bool) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: .text)

        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID2 = UUID().uuidString
        let attr2 = SyncAttributes(fileUUID: fileUUID2, mimeType: .text)
        
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
        
        SyncServer.session.sync()

        if copy {
            try! SyncServer.session.uploadCopy(localFile: url2, withAttributes: attr2)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url2, withAttributes: attr2)
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        getFileIndex(expectedFiles: [
            (fileUUID: fileUUID1, fileSize: nil),
            (fileUUID: fileUUID2, fileSize: nil)
        ])
        
        // Download and check the files
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url1 as URL, file: file1, masterVersion: masterVersion)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file2, masterVersion: masterVersion)
    }
    
    func testUploadImmutableOfDifferentFilesAcrossDifferentSyncsWorks() {
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: false)
    }
    
    func testUploadCopyOfDifferentFilesAcrossDifferentSyncsWorks() {
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: true)
    }
    
    func creationDateOfFileIsCorrect(copy: Bool) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
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
        
        SyncServer.session.sync()
        
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
        creationDateOfFileIsCorrect(copy: false)
    }
    
    func testThatCreationDateOfCopyFileIsCorrect() {
        creationDateOfFileIsCorrect(copy: true)
    }
    
    // TODO: *3* Test of upload file1, sync, upload file1, sync-- uploads both files.
    //      Needs to wait until we have version support.
}
