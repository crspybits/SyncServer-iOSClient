//
//  Client_GetAttributes.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 5/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class Client_GetAttributes: TestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetAttributesForAnUploadedFileWorks() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        guard let (_, uploadedAttr) = uploadSingleFileUsingSync(sharingGroupId: sharingGroupId, fileGroupUUID: UUID().uuidString, appMetaData: "Foobar") else {
            XCTFail()
            return
        }
        
        guard let attr = try? SyncServer.session.getAttributes(forUUID: uploadedAttr.fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(uploadedAttr.fileUUID == attr.fileUUID)
        XCTAssert(uploadedAttr.fileGroupUUID == attr.fileGroupUUID)
        XCTAssert(uploadedAttr.appMetaData == attr.appMetaData)
        XCTAssert(uploadedAttr.mimeType == attr.mimeType)
        XCTAssert(uploadedAttr.sharingGroupId == attr.sharingGroupId)
    }
    
    func testGetAttributesForADownloadedFileWorks() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, uploadedAttr) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 1)
        
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
        
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        guard let attr = try? SyncServer.session.getAttributes(forUUID: uploadedAttr.fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(uploadedAttr.fileUUID == attr.fileUUID)
        XCTAssert(uploadedAttr.fileGroupUUID == attr.fileGroupUUID)
        XCTAssert(uploadedAttr.appMetaData?.contents == attr.appMetaData)
        XCTAssert(uploadedAttr.mimeType == attr.mimeType)
    }
    
    func testGetAttributesForADeletedFileFails() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupId: sharingGroupId, mimeType: .text)
        
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
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        try! SyncServer.session.sync(sharingGroupId: sharingGroupId)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        guard let _ = try? SyncServer.session.getAttributes(forUUID: attr.fileUUID) else {
            return
        }
        
        XCTFail()
    }
    
    func testGetAttributesForANonExistentFileFails() {
        guard let _ = try? SyncServer.session.getAttributes(forUUID: UUID().uuidString) else {
            return
        }
        
        XCTFail()
    }
}
