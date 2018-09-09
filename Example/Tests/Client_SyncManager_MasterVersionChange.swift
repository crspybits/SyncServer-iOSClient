//
//  Client_SyncManager_MasterVersionChange.swift
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

// Test cases where the master version changes midway through the upload or download and forces a restart of the upload or download.

class Client_SyncManager_MasterVersionChange: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Demonstrate that we can "recover" from a master version change during upload. This "recovery" is really just the client side work necessary to deal with our lazy synchronization process.
    func testMasterVersionChangeDuringUpload() {
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

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        
        var singleUploadsCompleted = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 2)
                
                // This is three because one of the uploads is repeated when the master version is updated.
                XCTAssert(singleUploadsCompleted == 3, "Uploads actually completed: \(singleUploadsCompleted)")
                
                expectation2.fulfill()
                
            case .singleFileUploadComplete(_):
                singleUploadsCompleted += 1
                if singleUploadsCompleted == 1 {
                    // Serious faking of the master version change between the two file uploads. :). I was having too much problem trying to do an intervening upload right here.
                    CoreDataSync.perform(sessionName: Constants.coreDataName) {
                        guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) else {
                            XCTFail()
                            return
                        }
                        
                        sharingEntry.masterVersion -= 1
                    }
                }
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let _ = getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFiles: [
            (fileUUID: fileUUID1, fileSize: nil),
            (fileUUID: fileUUID2, fileSize: nil)
        ]) else {
            XCTFail()
            return
        }
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) else {
                XCTFail()
                return
            }
            
            masterVersion = sharingEntry.masterVersion
        }
        
        let file1 = ServerAPI.File(localURL: nil, fileUUID: fileUUID1, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file1, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testMasterVersionChangeOccuringOnDoneUploads() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)

        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted]

        let syncDone1Exp = self.expectation(description: "syncDone1Exp")
        let file1Exp = self.expectation(description: "file1Exp")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDone1Exp.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                file1Exp.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        // 1) Do the upload of the first file.
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        
        let syncDone2Exp = self.expectation(description: "syncDone2Exp")
        let fileUploadsCompletedExp = self.expectation(description: "fileUploadsCompleted")

        var singleUploadsCompleted = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDone2Exp.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                XCTAssert(singleUploadsCompleted == 2, "Uploads actually completed: \(singleUploadsCompleted)")
                fileUploadsCompletedExp.fulfill()
                
            case .singleFileUploadComplete(_):
                singleUploadsCompleted += 1
                if singleUploadsCompleted == 1 {
                    CoreDataSync.perform(sessionName: Constants.coreDataName) {
                        guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) else {
                            XCTFail()
                            return
                        }
                        
                        sharingEntry.masterVersion += 1
                    }
                }
                
            default:
                XCTFail()
            }
        }
        
        // 2) Do the upload of the second file, with a simulated master version change just after the upload. This tests getting the master version update on DoneUploads.

        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFiles: [
            (fileUUID: fileUUID2, fileSize: nil),
        ])
        
        var masterVersion:MasterVersionInt!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) else {
                XCTFail()
                return
            }
            
            masterVersion = sharingEntry.masterVersion
        }
        
        let file2 = ServerAPI.File(localURL: nil, fileUUID: fileUUID2, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: 0)
        onlyDownloadFile(comparisonFileURL: url as URL, file: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }

    func testMasterVersionUpdateOnUploadDeletion() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)

        // 1) Preparation: Upload a file, identified by UUID1. This is the file we'll delete below. We have to use the SyncServer.session client interface so that it will get recorded in the local meta data for the client.

        SyncServer.session.eventsDesired = [.syncDone]

        let syncDoneExp1 = self.expectation(description: "syncDoneExp1")
        
        var singleUploadsCompleted = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneExp1.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 20.0, handler: nil)
        
        // File to upload which will cause a SyncServer event which will allow us to upload fileUUID2
        let fileUUID3 = UUID().uuidString
        
        let attr3 = SyncAttributes(fileUUID: fileUUID3, sharingGroupUUID: sharingGroupUUID, mimeType: .text)

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete, .uploadDeletionsCompleted]
        
        let syncDoneExp2 = self.expectation(description: "syncDoneExp2")
        let fileUploadsCompletedExp = self.expectation(description: "fileUploadsCompletedExp")
        let uploadDeletionsCompletedExp = self.expectation(description: "uploadDeletionsCompletedExp")
                
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneExp2.fulfill()

            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                
                // This is two because the upload is repeated when the master version is updated.
                XCTAssert(singleUploadsCompleted == 2, "Uploads actually completed: \(singleUploadsCompleted)")
                
                fileUploadsCompletedExp.fulfill()
                
            case .uploadDeletionsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                uploadDeletionsCompletedExp.fulfill()
                
            case .singleFileUploadComplete(_):
                singleUploadsCompleted += 1
                if singleUploadsCompleted == 1 {
                    CoreDataSync.perform(sessionName: Constants.coreDataName) {
                        guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) else {
                            XCTFail()
                            return
                        }
                        
                        sharingEntry.masterVersion += 1
                    }
                }
                
            default:
                XCTFail()
            }
        }
        
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr3)
            try SyncServer.session.delete(fileWithUUID: fileUUID1)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testMasterVersionChangeDuringDownload() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Algorithm:
        // Upload two files *not* using the client upload.
        // Next, use the client interface to sync files.
        // When a single file has been downloaded, simulate a master version change.
        // 9/16/17; Since we're now doing the downloads incrementally, we should just get a total of 3 downloads.
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        var files = [FileUUIDURL]()

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileUUID3 = UUID().uuidString
        
        let fileURL1 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        let fileURL2 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe2", withExtension: "txt")!
        let fileURL3 = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe3", withExtension: "txt")!
        
        files = [
            (uuid: fileUUID1, url: fileURL1),
            (uuid: fileUUID2, url: fileURL2),
            (uuid: fileUUID3, url: fileURL3)
        ]
        
        guard let (_, _) = uploadFile(fileURL:fileURL1, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL2, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let syncDoneExp = self.expectation(description: "syncDoneExp")
        let shouldSaveDownloadsExp = self.expectation(description: "shouldSaveDownloadsExp")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneExp.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        var downloadCount = 0

        // This captures the second two downloads.
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url) = group[0].type {
                let attr = group[0].attr
                downloadCount += 1
                
                if downloadCount == 1 {
                    self.incrementMasterVersionFor(sharingGroupUUID: sharingGroupUUID)
                }
                
                // After a master version change, what happens to DownloadFileTracker(s) that were around before the change? They get deleted. And the server is again checked for downloads.
                
                XCTAssert(self.findAndRemoveFile(uuid: attr.fileUUID, url: url as URL, in: &files))

                if downloadCount >= 2 {
                    shouldSaveDownloadsExp.fulfill()
                }
            }
            else {
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
