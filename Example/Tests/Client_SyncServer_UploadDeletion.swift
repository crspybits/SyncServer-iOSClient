//
//  Client_SyncServer_UploadDeletion.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/7/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation

class Client_SyncServer_UploadDeletion: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        SyncServer.session.eventsDesired = .defaults
        super.tearDown()
    }
    
    @discardableResult
    func uploadDeletionWorksWhenWaitUntilAfterUpload() -> (SMRelativeLocalURL, SyncAttributes)? {
        guard let (url, attr) = uploadSingleFileUsingSync() else {
            XCTFail()
            return nil
        }
        
        SyncServer.session.eventsDesired = [.syncDone, .uploadDeletionsCompleted, .singleUploadDeletionComplete]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        let expectation3 = self.expectation(description: "test3")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
            
            case .uploadDeletionsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation2.fulfill()
                
            case .singleUploadDeletionComplete(fileUUID: let fileUUID):
                XCTAssert(attr.fileUUID == fileUUID)
                expectation3.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)

        // Need to make sure the file is marked as deleted on the server.
        guard let fileIndex = getFileIndex(expectedFiles: [(fileUUID: attr.fileUUID, fileSize: nil)]) else {
            XCTFail()
            return nil
        }
        
        guard fileIndex.count > 0, fileIndex[0].deleted else {
            XCTFail()
            return nil
        }

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let result = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID)
            XCTAssert(result!.deletedLocally)
        }
        
        return (url, attr)
    }
    
    func testThatUploadDeletionWorksWhenWaitUntilAfterUpload() {
        uploadDeletionWorksWhenWaitUntilAfterUpload()
    }
    
    func testThatUploadDeletionWorksWhenYouDoNotWaitUntilAfterUpload() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete, .uploadDeletionsCompleted, .singleUploadDeletionComplete]
        
        let syncDone1 = self.expectation(description: "test1")
        let syncDone2 = self.expectation(description: "test2")
        let expectation2 = self.expectation(description: "test3")
        let expectation3 = self.expectation(description: "test4")
        let expectation4 = self.expectation(description: "test5")
        let expectation5 = self.expectation(description: "test6")
        
        var syncDoneCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation2.fulfill()
                
            case .singleFileUploadComplete(attr: let attr):
                XCTAssert(attr.fileUUID == fileUUID)
                XCTAssert(attr.mimeType == .text)
                expectation3.fulfill()
                
            case .uploadDeletionsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation4.fulfill()
                
            case .singleUploadDeletionComplete(fileUUID: let fileUUID):
                XCTAssert(attr.fileUUID == fileUUID)
                expectation5.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // Need to make sure the file is marked as deleted on the server.
        guard let fileIndex = getFileIndex(expectedFiles: [(fileUUID: attr.fileUUID, fileSize: nil)]) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex[0].deleted)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let result = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID)
            XCTAssert(result!.deletedLocally)
        }
    }

    func testUploadImmediatelyFollowedByDeletionWorks() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        
        // Include events other than syncDone just as a means of ensuring they don't occur.
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete, .uploadDeletionsCompleted, .singleUploadDeletionComplete]
        
        let syncDone1 = self.expectation(description: "test1")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDone1.fulfill()

            default:
                XCTFail()
            }
        }
        
        // The file will never actually make it to the server-- since we delete it before sync'ing.
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let fileIndex = getFileIndex(expectedFiles: []) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex.count == 0)
    
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let result = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID)
            XCTAssert(result!.deletedLocally)
        }
    }
    
    func testDeletionImmediatelyFollowedByFileUploadFails() {
        guard let (url, attr) = uploadSingleFileUsingSync() else {
            XCTFail()
            return
        }

        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            XCTFail()
        } catch {
            // SyncServerError.fileQueuedForDeletion
        }
    }
    
    func testDeletionImmediatelyFollowedByAppMetaDataUploadFails() {
        guard let (_, attr) = uploadSingleFileUsingSync() else {
            XCTFail()
            return
        }

        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        
        do {
            var attr2 = attr
            attr2.appMetaData = "Foobar"
            try SyncServer.session.uploadAppMetaData(attr: attr)
            XCTFail()
        } catch {
            // SyncServerError.fileQueuedForDeletion
        }
    }
    
    func testThatDeletionWithSyncFollowedByFileUploadFails() {
        guard let (url, attr) = uploadDeletionWorksWhenWaitUntilAfterUpload() else {
            XCTFail()
            return
        }
        
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            XCTFail()
        } catch {
        }
    }
    
    // Delete, sync, upload in immediate succession -- of the same file should fail.
    func testThatDeletionWithSyncImmediatelyFollowedByFileUploadFails() {
        guard let (url, attr) = uploadSingleFileUsingSync() else {
            XCTFail()
            return
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let expectation1 = self.expectation(description: "test1")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        SyncServer.session.sync()
        
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            XCTFail()
        } catch {
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Delete, sync, delete in immediate succession -- second delete of the same file should fail.
    func testThatDeletionWithSyncImmediatelyFollowedByDeleteFails() {
        guard let (_, attr) = uploadSingleFileUsingSync() else {
            XCTFail()
            return
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let expectation1 = self.expectation(description: "test1")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        SyncServer.session.sync()
        
        do {
            try SyncServer.session.delete(fileWithUUID: attr.fileUUID)
            XCTFail()
        } catch {
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testThatDeletionWithSyncFollowedByAppMetaDataUploadFails() {
        guard let (_, attr) = uploadDeletionWorksWhenWaitUntilAfterUpload() else {
            XCTFail()
            return
        }
    
        do {
            var attr2 = attr
            attr2.appMetaData = "Foobar"
            try SyncServer.session.uploadAppMetaData(attr: attr)
            XCTFail()
        } catch {
            // SyncServerError.fileQueuedForDeletion
        }
    }
    
    func testDeletionOfFileWithBadUUIDFails() {
        let uuid = UUID().uuidString
        do {
            try SyncServer.session.delete(fileWithUUID: uuid)
            XCTFail()
        } catch {
        }
    }
    
    func testDeletionAttemptOfAFileAlreadyDeletedOnServerFails() {
        guard let (_, attr) = uploadDeletionWorksWhenWaitUntilAfterUpload() else {
            XCTFail()
            return
        }
        
        do {
            try SyncServer.session.delete(fileWithUUID: attr.fileUUID)
            XCTFail()
        } catch {
        }
    }
    
    func testMultipleFileDeletionWorks() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: .text)
        let fileUUID2 = UUID().uuidString
        let attr2 = SyncAttributes(fileUUID: fileUUID2, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let syncDone1 = self.expectation(description: "SyncDone1")
        let syncDone2 = self.expectation(description: "SyncDone2")

        var syncDoneCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                default:
                    XCTFail()
                }
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        SyncServer.session.sync()
        
        try! SyncServer.session.delete(fileWithUUID: attr1.fileUUID)
        try! SyncServer.session.delete(fileWithUUID: attr2.fileUUID)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // Need to make sure the file is marked as deleted on the server.
        guard let fileIndex = getFileIndex(expectedFiles:
            [(fileUUID: attr1.fileUUID!, fileSize: nil),
                (fileUUID: attr2.fileUUID!, fileSize: nil)
            ]) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex[0].deleted)
        XCTAssert(fileIndex[1].deleted)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let result1 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID1)
            XCTAssert(result1!.deletedLocally)
            let result2 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID2)
            XCTAssert(result2!.deletedLocally)
        }
    }
    
    func testMultipleSimultaneousFileDeletionWorks() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: .text)
        let fileUUID2 = UUID().uuidString
        let attr2 = SyncAttributes(fileUUID: fileUUID2, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let syncDone1 = self.expectation(description: "SyncDone1")
        let syncDone2 = self.expectation(description: "SyncDone2")

        var syncDoneCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                default:
                    XCTFail()
                }
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        SyncServer.session.sync()
        
        try! SyncServer.session.delete(filesWithUUIDs: [attr1.fileUUID, attr2.fileUUID])
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // Need to make sure the file is marked as deleted on the server.
        guard let fileIndex = getFileIndex(expectedFiles:
            [(fileUUID: attr1.fileUUID!, fileSize: nil),
                (fileUUID: attr2.fileUUID!, fileSize: nil)
            ]) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex[0].deleted)
        XCTAssert(fileIndex[1].deleted)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let result1 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID1)
            XCTAssert(result1!.deletedLocally)
            let result2 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID2)
            XCTAssert(result2!.deletedLocally)
        }
    }
    
    func testMultipleSimultaneousFileDeletionWithOneUnknownFileFails() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let syncDone1 = self.expectation(description: "SyncDone1")
        let syncDone2 = self.expectation(description: "SyncDone2")

        var syncDoneCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                default:
                    XCTFail()
                }
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        SyncServer.session.sync()
        
        var gotError = false
        do {
            try SyncServer.session.delete(filesWithUUIDs: [attr1.fileUUID,  "foobar"])
        } catch {
            gotError = true
        }
        
        XCTAssert(gotError)
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // TODO: *2* Attempt to delete a file with a version different than on the server. i.e., the local directory version is V1, but the server version is V2, V2 != V1. (This will have to wait until we have multi-version file support).
}
