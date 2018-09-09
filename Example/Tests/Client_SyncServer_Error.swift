//
//  Client_SyncServer_Error.swift
//  SyncServer
//
//  Created by Christopher Prince on 4/2/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_Error: TestCase {
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        super.tearDown()
        ServerAPI.session.failEndpoints = false
    }
    
    func testSyncFailure() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        ServerAPI.session.failEndpoints = true
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func syncFailureAfterOtherClientUpload(retry:Bool = false) {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // All endpoint calls will fail after this.
        ServerAPI.session.failEndpoints = true
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        // We failed to do the sync above because of the simulated endpoint failures.
        
        if retry {
            // Try the download again, this time turning off the simulated endpoint failure. Our expectation is that the download works this time.
            ServerAPI.session.failEndpoints = false
            
            let shouldSaveDownloadsExp = self.expectation(description: "shouldSaveDownloadsExp")
            
            let syncDoneExp = self.expectation(description: "syncDoneExp")
            SyncServer.session.eventsDesired = [.syncDone]
        
            syncServerEventOccurred = { event in
                switch event {
                case .syncDone:
                    syncDoneExp.fulfill()
                    
                default:
                    XCTFail()
                }
            }
            
            var downloadCount = 0
            
            syncServerFileGroupDownloadComplete = { group in
                if group.count == 1, case .file = group[0].type {
                    downloadCount += 1
                    XCTAssert(downloadCount == 1)
                    shouldSaveDownloadsExp.fulfill()
                }
                else {
                    XCTFail()
                }
            }
            
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            
            waitForExpectations(timeout: 10.0, handler: nil)
        }
    }
    
    func testSyncFailureAfterOtherClientUpload() {
        syncFailureAfterOtherClientUpload()
    }
    
    func testSyncFailureAfterOtherClientUploadWithRetry() {
        syncFailureAfterOtherClientUpload(retry:true)
    }

    private func failureAfterOneUpload(retry:Bool = false) {
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
        
        SyncServer.session.eventsDesired = [.singleFileUploadComplete]
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .singleFileUploadComplete:
                ServerAPI.session.failEndpoints = true
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 50.0, handler: nil)

        if retry {
            ServerAPI.session.failEndpoints = false

            SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
            
            let syncDone = self.expectation(description: "syncDone")
            let fileUploadsCompletedExp = self.expectation(description: "fileUploadsCompletedExp")
            
            var singleUploadsCompleted = 0
            
            syncServerEventOccurred = {event in
                switch event {
                case .syncDone:
                    syncDone.fulfill()
                    
                case .contentUploadsCompleted(numberOfFiles: let number):
                    XCTAssert(number == 2)
                    
                    // One because only a single file needs to be uploaded the second time-- the first was uploaded before the error.
                    XCTAssert(singleUploadsCompleted == 1, "Uploads actually completed: \(singleUploadsCompleted)")
                    
                    fileUploadsCompletedExp.fulfill()
                    
                case .singleFileUploadComplete(_):
                    singleUploadsCompleted += 1
                    
                default:
                    XCTFail()
                }
            }
            
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            
            waitForExpectations(timeout: 20.0, handler: nil)
        }
    }

    func testFailureAfterOneUpload() {
        failureAfterOneUpload()
    }
    
    func testFailureAfterOneUploadWithRetry() {
        failureAfterOneUpload(retry:true)
    }
    
    private func failureAfterOneDownload(sharingGroupUUID: String, retry:Bool = false) {
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        // The intent is to fail the next /DownloadFile/ endpoint request-- after the first one succeeds.
        var numberDownloads = 0
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                numberDownloads += 1
                if numberDownloads == 1 {
                    ServerAPI.session.failEndpoints = true
                }
            }
            else {
                XCTFail()
            }
        }
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }

        // 1) Get the download error.
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        waitForExpectations(timeout: 50.0, handler: nil)

        if retry {
            ServerAPI.session.failEndpoints = false

            SyncServer.session.eventsDesired = [.syncDone]
            
            let syncDone = self.expectation(description: "syncDone")
            let shouldSaveDownloadsExp = self.expectation(description: "shouldSaveDownloadsExp")
            
            syncServerEventOccurred = {event in
                switch event {
                case .syncDone:
                    syncDone.fulfill()
                    
                default:
                    XCTFail()
                }
            }
            
            syncServerFileGroupDownloadComplete = { group in
                if group.count == 1, case .file = group[0].type {
                    shouldSaveDownloadsExp.fulfill()
                }
                else {
                    XCTFail()
                }
            }
            
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            
            waitForExpectations(timeout: 20.0, handler: nil)
        }
    }
    
    func testFailureAfterOneDownload() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        failureAfterOneDownload(sharingGroupUUID: sharingGroupUUID)
    }
    
    func testFailureAfterOneDownloadWithRetry() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        failureAfterOneDownload(sharingGroupUUID: sharingGroupUUID, retry:true)
    }
}
