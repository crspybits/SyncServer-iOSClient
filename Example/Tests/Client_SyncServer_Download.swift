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
import SyncServer_Shared

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
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupId: sharingGroupId)
    }
    
    // Somehow this fails, when I run the test as a set, with `shouldSaveDownload` being nil.
    func testDownloadTwoFilesBackToBack() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        Log.msg("Start of testDownloadTwoFilesBackToBack")

        let initialDeviceUUID = self.deviceUUID

        // First upload two files.
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)
        
        let expectation = self.expectation(description: "test1")
        let willStartDownloadsExp = self.expectation(description: "willStartDownloads")

        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        Log.msg("Before assignment to shouldSaveDownload")
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                downloadCount += 1
                XCTAssert(downloadCount <= 2)
                if downloadCount >= 2 {
                    expectation.fulfill()
                }
            }
            else {
                XCTFail()
            }
        }
        
        SyncServer.session.eventsDesired = [.willStartDownloads, .syncDone]
        SyncServer.session.delegate = self
        let done = self.expectation(description: "done")

        syncServerEventOccurred = {event in
            switch event {
            case .willStartDownloads(numberContentDownloads: let numberContentDownloads, _):
                XCTAssert(numberContentDownloads == 2)
                willStartDownloadsExp.fulfill()
            
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        Log.msg("After assignment to shouldSaveDownload")
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        XCTAssert(initialDeviceUUID != ServerAPI.session.delegate.deviceUUID(forServerAPI: ServerAPI.session))
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadWithMetaData() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        let appMetaData = AppMetaData(version: 0, contents: "Some app meta data")
        doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupId: sharingGroupId, appMetaData: appMetaData)
    }
    
    func testThatResetWorksAfterDownload() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        let appMetaData = AppMetaData(version: 0, contents: "Some app meta data")
        doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupId: sharingGroupId, appMetaData: appMetaData)
        
        do {
            try SyncServer.session.reset(type: .all)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
        
        let sharingGroupIds = sharingGroups.filter {$0.sharingGroupId != nil}.map {$0.sharingGroupId!}
        assertThereIsNoMetaData(sharingGroupIds: sharingGroupIds)
    }
    
    // TODO: *2* This test typically fails when run as a group with other tests. Why?
    func testGetStats() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        // 1) Get a download deletion ready
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupId: sharingGroupId)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)
        
        // 2) Get a file download ready
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID, serverMasterVersion: masterVersion+1) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion+1, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)
        
        let uploadDeletionExp = self.expectation(description: "uploadDeletion")
        
        // 3) Now, check to make sure we have what we expect
        
        SyncServer.session.getStats(sharingGroupId: sharingGroupId) { stats in
            guard let stats = stats else {
                XCTFail()
                return
            }
            
            XCTAssert(stats.contentDownloadsAvailable == 1)
            XCTAssert(stats.downloadDeletionsAvailable == 1)
            uploadDeletionExp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
