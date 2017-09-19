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

class Client_SyncServer_Error: TestCase {
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        super.tearDown()
        ServerAPI.session.failEndpoints = false
    }
    
    func testSyncFailure() {
        ServerAPI.session.failEndpoints = true
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func syncFailureAfterOtherClientUpload(retry:Bool = false) {
        let masterVersion = getMasterVersion()
        
        let fileUUID1 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        ServerAPI.session.failEndpoints = true
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        if retry {
            ServerAPI.session.failEndpoints = false
            
            let syncDoneExp = self.expectation(description: "syncDoneExp")
            let shouldSaveDownloadsExp = self.expectation(description: "shouldSaveDownloadsExp")

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
            shouldSaveDownload = { url, attr in
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                shouldSaveDownloadsExp.fulfill()
            }
            
            SyncServer.session.sync()
            
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
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let attr1 = SyncAttributes(fileUUID: fileUUID1, mimeType: "text/plain")
        let attr2 = SyncAttributes(fileUUID: fileUUID2, mimeType: "text/plain")
    
        let previousSyncServerSingleFileUploadCompleted = self.syncServerSingleFileUploadCompleted
        SyncManager.session.testingDelegate = self
        
        syncServerSingleFileUploadCompleted = {next in
            ServerAPI.session.failEndpoints = true

            self.syncServerSingleFileUploadCompleted = previousSyncServerSingleFileUploadCompleted
            SyncManager.session.testingDelegate = nil
            next()
        }
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 50.0, handler: nil)

        if retry {
            ServerAPI.session.failEndpoints = false

            SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted, .singleFileUploadComplete]
            
            let syncDone = self.expectation(description: "syncDone")
            let fileUploadsCompletedExp = self.expectation(description: "fileUploadsCompletedExp")
            
            var singleUploadsCompleted = 0
            
            syncServerEventOccurred = {event in
                switch event {
                case .syncDone:
                    syncDone.fulfill()
                    
                case .fileUploadsCompleted(numberOfFiles: let number):
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
            
            SyncServer.session.sync()
            
            waitForExpectations(timeout: 20.0, handler: nil)
        }
    }
    
    func testFailureAfterOneUpload() {
        failureAfterOneUpload()
    }
    
    func testFailureAfterOneUploadWithRetry() {
        failureAfterOneUpload(retry:true)
    }
    
    private func failureAfterOneDownload(retry:Bool = false) {
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        
        let masterVersion = getMasterVersion()
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        SyncManager.session.testingDelegate = self

        let previousSyncServerSingleFileDownloadCompleted = self.syncServerSingleFileDownloadCompleted
    
        syncServerSingleFileDownloadCompleted = { url, attr, next in
            // The intent is to fail the next /DownloadFile/ endpoint request-- after the first one succeeds.
            ServerAPI.session.failEndpoints = true

            self.syncServerSingleFileDownloadCompleted = previousSyncServerSingleFileDownloadCompleted
            SyncManager.session.testingDelegate = nil
            next()
        }
        
        SyncServer.session.eventsDesired = []
        let errorExp = self.expectation(description: "errorExp1")

        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }

        // 1) Get the download error.
        SyncServer.session.sync()
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
            
            // 9/16/17; Since we are now doing downloads incrementally (and deleting the DownloadFileTracker's after each one), we'll just get a single download here.
            shouldSaveDownload = { url, attr in
                shouldSaveDownloadsExp.fulfill()
            }
            
            SyncServer.session.sync()
            
            waitForExpectations(timeout: 20.0, handler: nil)
        }
    }
    
    func testFailureAfterOneDownload() {
        failureAfterOneDownload()
    }
    
    func testFailureAfterOneDownloadWithRetry() {
        failureAfterOneDownload(retry:true)
    } 
}
