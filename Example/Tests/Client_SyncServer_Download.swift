//
//  Client_SyncServer_Download.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/22/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation

class Client_SyncServer_Download: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // TODO: *1* Other download test cases using .sync()
    
    func testDownloadByDifferentDeviceUUIDThanUpload() {
         doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: "text/plain")
    }
    
    // Somehow this fails, when I run the test as a set, with `shouldSaveDownload` being nil.
    func testDownloadTwoFilesBackToBack() {
        Log.msg("Start of testDownloadTwoFilesBackToBack")

        let initialDeviceUUID = self.deviceUUID

        // First upload two files.
        let masterVersion = getMasterVersion()
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        let expectation = self.expectation(description: "test1")
        let willStartDownloadsExp = self.expectation(description: "willStartDownloads")
        
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        Log.msg("Before assignment to shouldSaveDownload")
        
        shouldSaveDownload = { url, attr in
            downloadCount += 1
            XCTAssert(downloadCount <= 2)
            if downloadCount >= 2 {
                expectation.fulfill()
            }
        }
        
        SyncServer.session.eventsDesired = [.willStartDownloads]
        
        syncServerEventOccurred = {event in
            switch event {
            case .willStartDownloads(numberDownloads: let numberDownloads):
                XCTAssert(numberDownloads == 2)
                willStartDownloadsExp.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        Log.msg("After assignment to shouldSaveDownload")
        
        // Next, initiate the download using .sync()
        SyncServer.session.sync()
        
        XCTAssert(initialDeviceUUID != ServerAPI.session.delegate.deviceUUID(forServerAPI: ServerAPI.session))
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadWithMetaData() {
         doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: "text/plain", appMetaData: "Some app meta data")
    }
    
    // TODO: *2* This test typically fails when run as a group with other tests. Why?
    func testGetStats() {
        // 1) Get a download deletion ready
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // 2) Get a file download ready
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion+1) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion+1, expectedNumberUploads: 1)
        
        let uploadDeletionExp = self.expectation(description: "uploadDeletion")
        
        // 3) Now, check to make sure we have what we expect
        
        SyncServer.session.getStats { stats in
            XCTAssert(stats!.downloadsAvailable == 1)
            XCTAssert(stats!.downloadDeletionsAvailable == 1)
            uploadDeletionExp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
