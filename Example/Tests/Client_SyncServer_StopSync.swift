//
//  Client_SyncServer_StopSync.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 9/18/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation

class Client_SyncServer_StopSync: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatStopSyncDoesNothing() {
        let finishExp = self.expectation(description: "FileUploads")

        SyncServer.session.eventsDesired = .all
        
        syncServerEventOccurred = {event in
            switch event {
            default:
                XCTFail()
            }
        }
        
        TimedCallback.withDuration(1.0) {
            finishExp.fulfill()
        }
        
        SyncServer.session.stopSync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync before an upload. Expect:
         1) Upload not to occur
         2) If you call sync again, expect it to occur normally.
     */
    func testStopSyncBeforeUpload() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncStarted, .syncStopping, .contentUploadsCompleted]
        let syncStarted = self.expectation(description: "SyncStarted")
        let syncStopping = self.expectation(description: "SyncStopping")
        let fileUploads = self.expectation(description: "FileUploads")

        var alreadyStopped = false

        syncServerEventOccurred = {event in
            switch event {
            case .syncStarted:
                if !alreadyStopped {
                    SyncServer.session.stopSync()
                    syncStarted.fulfill()
                }
            
            case .syncStopping:
                syncStopping.fulfill()
                alreadyStopped = true
                
                // Don't do the next .sync from here because the stop sync is effectively pending.
                // SyncServer.session.sync()
                // Also don't do it from .syncDone-- effectively same issue there.
                
                // But, should be good after a delay.
                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }
                
            case .contentUploadsCompleted:
                XCTAssert(alreadyStopped)
                fileUploads.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync between two uploads. Expect:
         1) second one to not be done.
         2) If you call sync again, expect second to occur normally.
    */
    func testStopSyncBetweenTwoUploads() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncStopping, .contentUploadsCompleted, .singleFileUploadComplete]
        
        let syncStopping = self.expectation(description: "SyncStopping")
        let fileUploads = self.expectation(description: "FileUploads")
        let singleUploadExp1 = self.expectation(description: "SingleUpload1")
        let singleUploadExp2 = self.expectation(description: "SingleUpload2")
        var alreadyStopped = false

        syncServerEventOccurred = { event in
            switch event {
            case .syncStopping:
                syncStopping.fulfill()
                alreadyStopped = true
                
                // Don't do the next .sync from here because the stop sync is effectively pending.
                // SyncServer.session.sync()
                // Also don't do it from .syncDone-- effectively same issue there.
                
                // But, should be good after a delay.
                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }
                
            case .singleFileUploadComplete:
                if alreadyStopped {
                    singleUploadExp2.fulfill()
                }
                else {
                    singleUploadExp1.fulfill()
                    SyncServer.session.stopSync()
                }
                
            case .contentUploadsCompleted:
                XCTAssert(alreadyStopped)
                fileUploads.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync before a download. Expect:
         1) Download not to occur.
         2) If you call sync again, expect download to occur normally.
    */
    func testStopSyncBeforeDownload() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Upload a file, without using client interface, so it'll download when we do a sync.
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:nil) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        SyncServer.session.eventsDesired = [.syncStopping, .syncStarted]
        
        let syncStartExp = self.expectation(description: "SyncStart")
        let syncStoppingExp = self.expectation(description: "SyncStopping")
        let shouldSaveDownloadExp = self.expectation(description: "ShouldSaveDownload")
        
        var alreadyStopped = false
        var numberSyncStarted = 0
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncStarted:
                numberSyncStarted += 1
                if numberSyncStarted == 1 {
                    syncStartExp.fulfill()
                    SyncServer.session.stopSync()
                }
                else if numberSyncStarted > 2 {
                    XCTFail()
                }
                
            case .syncStopping:
                syncStoppingExp.fulfill()
                alreadyStopped = true
                
                // Don't do the next .sync from here because the stop sync is effectively pending.
                // SyncServer.session.sync()
                // Also don't do it from .syncDone-- effectively same issue there.
                
                // But, should be good after a delay.
                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                XCTAssert(alreadyStopped)
                shouldSaveDownloadExp.fulfill()
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync between two downloads. Expect:
         1) Download second not to occur.
         2) If you call sync again, expect 2nd download to occur normally.
    */
    func testStopSyncBetweenTwoDownloads() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Upload two files, without using client interface, so they will download when we do a sync.
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, appMetaData:nil) else {
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, appMetaData:nil) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)

        SyncServer.session.eventsDesired = [.syncStopping]
        
        let syncStoppingExp = self.expectation(description: "SyncStopping")
        let shouldSaveDownloadExp1 = self.expectation(description: "ShouldSaveDownload1")
        let shouldSaveDownloadExp2 = self.expectation(description: "ShouldSaveDownload2")

        var alreadyStopped = false

        syncServerEventOccurred = { event in
            switch event {
            case .syncStopping:
                syncStoppingExp.fulfill()
                alreadyStopped = true
                
                // Don't do the next .sync from here because the stop sync is effectively pending.
                // SyncServer.session.sync()
                // Also don't do it from .syncDone-- effectively same issue there.
                
                // But, should be good after a delay.
                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                if alreadyStopped {
                    shouldSaveDownloadExp2.fulfill()
                }
                else {
                    shouldSaveDownloadExp1.fulfill()
                    SyncServer.session.stopSync()
                }
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync between two upload deletions. Expect:
         1) First to complete.
         2) If you call sync again, expect 2nd to occur normally.
    */
    func testStopSyncBetweenTwoUploadDeletions() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let (_, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID),
            let (_, attr2) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        SyncServer.session.eventsDesired = [.syncStopping, .singleUploadDeletionComplete]
        
        let syncStoppingExp = self.expectation(description: "SyncStopping")
        let singleUploadDeletion1 = self.expectation(description: "SingleUploadDeletion1")
        let singleUploadDeletion2 = self.expectation(description: "SingleUploadDeletion2")

        var alreadyStopped = false

        syncServerEventOccurred = { event in
            switch event {
            case .singleUploadDeletionComplete:
                if alreadyStopped {
                    singleUploadDeletion2.fulfill()
                }
                else {
                    singleUploadDeletion1.fulfill()
                    SyncServer.session.stopSync()
                }
                
            case .syncStopping:
                syncStoppingExp.fulfill()
                alreadyStopped = true
                
                // But, should be good after a delay.
                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }

            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr1.fileUUID)
        try! SyncServer.session.delete(fileWithUUID: attr2.fileUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Do two stop sync's successively. E.g., call it before one upload. Restart.
     Allow upload. Call it before second upload. Restart. Should eventually get both uploads done.
    */
    func testTwoStopSyncs() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncStopping, .syncStarted, .singleFileUploadComplete, .contentUploadsCompleted]
        
        let syncStartExp = self.expectation(description: "SyncStart")
        let fileUploads = self.expectation(description: "FileUploads")
        let singleUploadExp1 = self.expectation(description: "SingleUpload1")
        let singleUploadExp2 = self.expectation(description: "SingleUpload2")
        var numberOfStops = 0

        syncServerEventOccurred = { event in
            switch event {
            case .syncStarted:
                if numberOfStops == 0 {
                    syncStartExp.fulfill()
                    SyncServer.session.stopSync()
                }
                
            case .syncStopping:
                numberOfStops += 1

                TimedCallback.withDuration(1.0) {
                    try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
                }
                
            case .singleFileUploadComplete:
                if numberOfStops == 1 {
                    singleUploadExp1.fulfill()
                    SyncServer.session.stopSync()
                }
                else {
                    singleUploadExp2.fulfill()
                }
                
            case .contentUploadsCompleted:
                XCTAssert(numberOfStops == 2)
                fileUploads.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Call stop sync after 1 of 2 downloads. After stopping, upload delete remaining file. Call sync again. We should get a master version update.
    */
   func testStopSyncWithMasterVersionChange() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
    
        // 1) Upload two files, without using client interface, so they will download when we do a sync.
        guard let masterVersion = getMasterVersion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
    
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        var files = [FileUUIDURL]()
        files = [
            (uuid: fileUUID1, url: url as URL),
            (uuid: fileUUID2, url: url as URL)
        ]
    
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, appMetaData:nil) else {
            return
        }
    
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion, appMetaData:nil) else {
            return
        }
    
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
    
        // 2) Do the first stop sync
        let shouldSaveDownloadExp1 = self.expectation(description: "ShouldSaveDownload1")
    
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url) = group[0].type {
                let attr = group[0].attr
                SyncServer.session.stopSync()
                XCTAssert(self.findAndRemoveFile(uuid: attr.fileUUID, url: url as URL, in: &files))
                shouldSaveDownloadExp1.fulfill()
            }
            else {
                XCTFail()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
    
        waitForExpectations(timeout: 10.0, handler: nil)
    
        // 3) Delete remaining file-- Don't use the client sync interface so that we force a master version update that we're not aware of in the context of the client sync interface.
    let fileToDelete = ServerAPI.FileToDelete(fileUUID: files[0].uuid, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
    doneUploads(masterVersion: masterVersion+1, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
    
        // 4) Do another sync. Should not get a download deletion callback because the client doesn't know about that file.
    
        SyncServer.session.eventsDesired = [.syncDone]
    
        let syncDoneExp = self.expectation(description: "SyncDone")
    
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                syncDoneExp.fulfill()
                
            default:
                XCTFail()
            }
        }
    
        syncServerFileGroupDownloadComplete = { group in
            XCTFail()
        }
    
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
