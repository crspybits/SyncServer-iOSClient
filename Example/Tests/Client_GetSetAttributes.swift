//
//  Client_GetSetAttributes.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 5/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class Client_GetSetAttributes: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetAttributesForAnUploadedFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, uploadedAttr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID: UUID().uuidString, appMetaData: "Foobar") else {
            XCTFail()
            return
        }
        
        guard let attr = try? SyncServer.session.getAttributes(forFileUUID: uploadedAttr.fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(uploadedAttr.fileUUID == attr.fileUUID)
        XCTAssert(uploadedAttr.fileGroupUUID == attr.fileGroupUUID)
        XCTAssert(uploadedAttr.appMetaData == attr.appMetaData)
        XCTAssert(uploadedAttr.mimeType == attr.mimeType)
        XCTAssert(uploadedAttr.sharingGroupUUID == attr.sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testGetAttributesForADownloadedFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let uploadedAttr = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        let download = self.expectation(description: "test1")
        let done = self.expectation(description: "done")

        syncServerFileGroupDownloadComplete = { group in
            XCTAssert(group.count == 1)
            download.fulfill()
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        guard let attr = try? SyncServer.session.getAttributes(forFileUUID: uploadedAttr.fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(uploadedAttr.fileUUID == attr.fileUUID)
        XCTAssert(uploadedAttr.fileGroupUUID == attr.fileGroupUUID)
        XCTAssert(uploadedAttr.appMetaData?.contents == attr.appMetaData)
        XCTAssert(uploadedAttr.mimeType == attr.mimeType)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testGetAttributesForADeletedFileFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone]
        
        let syncDone = self.expectation(description: "test1")
        
        var syncDoneCount = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                syncDoneCount += 1
                if syncDoneCount == 2 {
                    syncDone.fulfill()
                }
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let _ = try? SyncServer.session.getAttributes(forFileUUID: attr.fileUUID) else {
            return
        }
        
        XCTFail()
    }
    
    func testGetAttributesForANonExistentFileFails() {
        guard let _ = try? SyncServer.session.getAttributes(forFileUUID: UUID().uuidString) else {
            return
        }
        
        XCTFail()
    }
    
    func testRequestDownloadFailsWithBadUUID() {
        do {
            try SyncServer.session.requestDownload(forFileUUID: UUID().uuidString)
            XCTFail()
        }
        catch {
        }
    }
    
    func testRequestDownloadForAnUploadedFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, uploadedAttr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileGroupUUID: UUID().uuidString, appMetaData: "Foobar") else {
            XCTFail()
            return
        }
        
        try! SyncServer.session.requestDownload(forFileUUID: uploadedAttr.fileUUID)
        
        let expectation = self.expectation(description: "test1")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                let attr = group[0].attr
                XCTAssert(attr.fileUUID == uploadedAttr.fileUUID)
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                expectation.fulfill()
            }
            else {
                XCTFail()
            }
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        let done = self.expectation(description: "done")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
}
