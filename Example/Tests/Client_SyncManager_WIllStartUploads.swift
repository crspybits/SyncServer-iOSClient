//
//  Client_SyncManager_WIllStartUploads.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 12/26/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncManager_WillStartUploads: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatWillUploadEventIsNotTriggeredForNoUploads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        SyncServer.session.eventsDesired = [.syncDone, .willStartUploads]
        let expectation1 = self.expectation(description: "test1")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .willStartUploads:
                XCTFail()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatWillUploadEventIsTriggeredForOneFileUpload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.willStartUploads, .syncDone]
        SyncServer.session.delegate = self
        let willStartUploadsExp = self.expectation(description: "willStartUploadsExp")
        let done = self.expectation(description: "done")
        
        syncServerEventOccurred = {event in
            switch event {
            case .willStartUploads(numberContentUploads: let numberContentUploads, numberUploadDeletions: let numberUploadDeletions, _):
                XCTAssert(numberContentUploads == 1)
                XCTAssert(numberUploadDeletions == 0)
                willStartUploadsExp.fulfill()
            
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID:sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testThatWillUploadEventIsTriggeredForOneUploadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        SyncServer.session.eventsDesired = [.willStartUploads, .syncDone]
        SyncServer.session.delegate = self

        let willStartUploadsExp = self.expectation(description: "willStartUploadsExp")
        let done = self.expectation(description: "done")
        
        syncServerEventOccurred = {event in
            switch event {
            case .willStartUploads(numberContentUploads: let numberContentUploads, numberUploadDeletions: let numberUploadDeletions, _):
                XCTAssert(numberContentUploads == 0)
                XCTAssert(numberUploadDeletions == 1)
                willStartUploadsExp.fulfill()
            
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testThatWillUploadEventIsTriggeredForFileUploadAndUploadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID

        guard let (_, deletionAttr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString
        let uploadAttr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.willStartUploads, .syncDone]
        SyncServer.session.delegate = self
        
        let willStartUploadsExp = self.expectation(description: "willStartUploadsExp")
        let done = self.expectation(description: "done")

        syncServerEventOccurred = {event in
            switch event {
            case .willStartUploads(numberContentUploads: let numberContentUploads, numberUploadDeletions: let numberUploadDeletions, _):
                XCTAssert(numberContentUploads == 1)
                XCTAssert(numberUploadDeletions == 1)
                willStartUploadsExp.fulfill()
            
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: deletionAttr.fileUUID)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: uploadAttr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
}
