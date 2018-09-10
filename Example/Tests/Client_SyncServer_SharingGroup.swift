//
//  Client_SyncServer_SharingGroup.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 7/22/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_SharingGroup: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func upload(uploadCopy: Bool, sharingGroupUUID: String, failureExpected: Bool = false) {
        let fileUUID = UUID().uuidString
        var url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        
        if uploadCopy {
            guard let copyOfFileURL = FilesMisc.newTempFileURL() else {
                XCTFail()
                return
            }
            
            try! FileManager.default.copyItem(at: url as URL, to: copyOfFileURL as URL)
            url = copyOfFileURL
        }

        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        do {
            if uploadCopy {
                try SyncServer.session.uploadCopy(localFile: url, withAttributes: attr)
            }
            else {
                try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            }
            if failureExpected {
                XCTFail()
            }
        } catch {
            if !failureExpected {
                XCTFail()
            }
        }
    }
    
    func testMultipleSharingGroupsUploadImmutableFileBeforeSyncFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        upload(uploadCopy: false, sharingGroupUUID: sharingGroupUUID)
        let badSharingGroupUUID = UUID().uuidString
        upload(uploadCopy: false, sharingGroupUUID: badSharingGroupUUID, failureExpected: true)
    }
    
    func testMultipleSharingGroupsUploadCopyFileBeforeSyncFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        upload(uploadCopy: true, sharingGroupUUID: sharingGroupUUID)
        let badSharingGroupUUID = UUID().uuidString
        upload(uploadCopy: true, sharingGroupUUID: badSharingGroupUUID, failureExpected: true)
    }

    // MARK: Creating sharing groups
    
    func createSharingGroup(name: String? = nil) -> String? {
        var result: String?
        
        let sharingGroupUUID = UUID().uuidString
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: name)
        } catch {
            XCTFail()
            return nil
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        let expectation1 = self.expectation(description: "done")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                result = sharingGroupUUID
                expectation1.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20, handler: nil)
        
        return result
    }
    
    func createSharingGroupUsingSyncWorks(name: String?) {
        let initialNumberSharingGroups = SyncServer.session.sharingGroups.count
        
        guard let sharingGroupUUID = createSharingGroup(name: name) else {
            XCTFail()
            return
        }
        
        // Check the local sharing groups-- should have our new one.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.deletedOnServer else {
                XCTFail()
                return
            }
            
            XCTAssert(sharingEntry.sharingGroupName == name)
        }
        
        guard initialNumberSharingGroups + 1 == SyncServer.session.sharingGroups.count else {
            XCTFail()
            return
        }
        
        let filtered = SyncServer.session.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard filtered.count == 1, filtered[0].sharingGroupName == name else {
            XCTFail()
            return
        }
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        // Should still have our new one.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.deletedOnServer else {
                XCTFail()
                return
            }
            XCTAssert(sharingEntry.sharingGroupName == name)
        }
        
        guard initialNumberSharingGroups + 1 == SyncServer.session.sharingGroups.count else {
            XCTFail()
            return
        }
        
        let filtered2 = SyncServer.session.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard filtered2.count == 1, filtered[0].sharingGroupName == name else {
            XCTFail()
            return
        }
    }
    
    func testCreateSharingGroupWithoutNameUsingSyncWorks() {
        createSharingGroupUsingSyncWorks(name: nil)
    }
    
    func testCreateSharingGroupWithNameUsingSyncWorks() {
        createSharingGroupUsingSyncWorks(name: UUID().uuidString)
    }

    // Failure when doing an upload of a bad sharing group.
    func testUploadFileToBadSharingGroupFails() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        
        let sharingGroupUUID = UUID().uuidString
        let fileUUID = UUID().uuidString

        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            XCTFail()
        } catch {
        }
    }
    
    // Failure when creating duplicate sharing group.
    func testCreatingDuplicateSharingGroupAfterFails() {
        guard let sharingGroupUUID = createSharingGroup() else {
            XCTFail()
            return
        }
        
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID)
            XCTFail()
        } catch {
        }
    }
    
    func testCreatingDuplicateSharingGroupBeforeSyncFails() {
        let sharingGroupUUID = UUID().uuidString
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID)
        } catch {
            XCTFail()
        }
        
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID)
            XCTFail()
        } catch {
        }
    }
    
    // Create a sharing group, create a second sharing group: Should fail.
    func testCreatingTwoSharingGroupsSuccessivelyFails() {
        let sharingGroupUUID1 = UUID().uuidString
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID1)
        } catch {
            XCTFail()
        }
        
        let sharingGroupUUID2 = UUID().uuidString
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID2)
            XCTFail()
        } catch {
        }
    }
    
    // Try to do a sync with an unknown sharing group
    func testSyncWithBadSharingGroupFails() {
        do {
            try SyncServer.session.sync(sharingGroupUUID: UUID().uuidString)
            XCTFail()
        } catch {
        }
    }
    
    // MARK: Updating sharing groups
}
