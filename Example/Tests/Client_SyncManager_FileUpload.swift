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

    func uploadASingleFile(copy:Bool, sharingGroupId: SharingGroupId) {
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupId: sharingGroupId, uploadCopy: copy) else {
            XCTFail()
            return
        }
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: [(fileUUID: attr.fileUUID, fileSize: nil)])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: attr.fileUUID, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    func testThatUploadingASingleImmutableFileWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadASingleFile(copy:false, sharingGroupId: sharingGroupId)
    }
    
    func testThatUploadingASingleCopyFileWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadASingleFile(copy:true, sharingGroupId: sharingGroupId)
    }
    
    func uploadTwoSeparateFilesWorks(copy:Bool, sharingGroupId: SharingGroupId) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupId: sharingGroupId, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupId: sharingGroupId, mimeType: .text)

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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: [
            (fileUUID: fileUUID1, fileSize: nil),
            (fileUUID: fileUUID2, fileSize: nil)
        ])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file1, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file2, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    func testThatUploadingTwoSeparateImmutableFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadTwoSeparateFilesWorks(copy:false, sharingGroupId: sharingGroupId)
    }
    
    func testThatUploadingTwoSeparateCopyFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadTwoSeparateFilesWorks(copy:true, sharingGroupId: sharingGroupId)
    }

    // TODO: *2* file will have deleted flag set in local Directory.
    // This is commented out until we do multi-version files.
/*
    func testThatUploadOfPreviouslyDeletedFileFails() {
    }
*/

    func addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy:Bool, sharingGroupId: SharingGroupId) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .text)
        
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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: [(fileUUID: fileUUID, fileSize: nil)])
        
        // Download the file and make sure it corresponds to url2
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    func testThatAddingSameImmutableFileToUploadQueueTwiceBeforeSyncReplaces() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: false, sharingGroupId: sharingGroupId)
    }
    
    func testThatAddingSameCopyFileToUploadQueueTwiceBeforeSyncReplaces() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        addingSameFileToUploadQueueTwiceBeforeSyncReplaces(copy: true, sharingGroupId: sharingGroupId)
    }
    
    func changingTheMimeTypeOnSecondUploadFails(copy: Bool, sharingGroupId: SharingGroupId) {
       let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        
        let attr1 = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .text)
        
        // Different mime type for second upload attempt.
        let attr2 = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .jpeg)
        
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
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        changingTheMimeTypeOnSecondUploadFails(copy: false, sharingGroupId: sharingGroupId)
    }
    
    func testThatChangingTheMimeTypeOnSecondUploadCopyFails() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        changingTheMimeTypeOnSecondUploadFails(copy: true, sharingGroupId: sharingGroupId)
    }

    func syncAferCompleteUploadWorks(copy: Bool, sharingGroupId: SharingGroupId) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .text)
        
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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: [(fileUUID: fileUUID, fileSize: nil)])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    func testSyncAferCompleteUploadImmutableWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        syncAferCompleteUploadWorks(copy: false, sharingGroupId: sharingGroupId)
    }
    
    func testSyncAferCompleteUploadCopyWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        syncAferCompleteUploadWorks(copy: true, sharingGroupId: sharingGroupId)
    }
    
    func uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: Bool, sharingGroupId: SharingGroupId) {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupId: sharingGroupId, mimeType: .text)

        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let fileUUID2 = UUID().uuidString
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupId: sharingGroupId, mimeType: .text)
        
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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)

        if copy {
            try! SyncServer.session.uploadCopy(localFile: url2, withAttributes: attr2)
        }
        else {
            try! SyncServer.session.uploadImmutable(localFile: url2, withAttributes: attr2)
        }
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        getFileIndex(sharingGroupId: sharingGroupId, expectedFiles: [
            (fileUUID: fileUUID1, fileSize: nil),
            (fileUUID: fileUUID2, fileSize: nil)
        ])
        
        // Download and check the files
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            masterVersion = Singleton.get().masterVersion
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url1 as URL, file: file1, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupId: sharingGroupId, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url2 as URL, file: file2, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    func testUploadImmutableOfDifferentFilesAcrossDifferentSyncsWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: false, sharingGroupId: sharingGroupId)
    }
    
    func testUploadCopyOfDifferentFilesAcrossDifferentSyncsWorks() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        uploadOfDifferentFilesAcrossDifferentSyncsWorks(copy: true, sharingGroupId: sharingGroupId)
    }
    
    func creationDateOfFileIsCorrect(copy: Bool, sharingGroupId: SharingGroupId) {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .text)
        
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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
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
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        creationDateOfFileIsCorrect(copy: false, sharingGroupId: sharingGroupId)
    }
    
    func testThatCreationDateOfCopyFileIsCorrect() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        creationDateOfFileIsCorrect(copy: true, sharingGroupId: sharingGroupId)
    }
    
    // TODO: *3* Test of upload file1, sync, upload file1, sync-- uploads both files.
    //      Needs to wait until we have version support.
}
