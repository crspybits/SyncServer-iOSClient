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
        
        SyncServer.session.eventsDesired = [.syncDone, .sharingGroupUploadOperationCompleted]
        let expectation1 = self.expectation(description: "done")
        let expectation2 = self.expectation(description: "sgoperation")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                result = sharingGroupUUID
                expectation1.fulfill()
                
            case .sharingGroupUploadOperationCompleted:
                expectation2.fulfill()
                
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
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
            
            XCTAssert(sharingEntry.sharingGroupName == name)
        }
        
        assertUploadTrackersAreReset()
        
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
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
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
    
    
    func testDeleteFileFromBadSharingGroupFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)

        do {
            try SyncServer.session.sync(sharingGroupUUID: UUID().uuidString)
            XCTFail()
        } catch {
        }
    }
    
    func testUploadThenSyncToBadSharingGroupUUIDFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID = UUID().uuidString

        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        do {
            try SyncServer.session.sync(sharingGroupUUID: UUID().uuidString)
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
    
    func changeSharingGroupName(twice: Bool = false) {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID

        if twice {
            let newSharingGroupName0 = UUID().uuidString
            try! SyncServer.session.updateSharingGroup(sharingGroupUUID: sharingGroupUUID, newSharingGroupName: newSharingGroupName0)
        }
        
        let newSharingGroupName = UUID().uuidString
        try! SyncServer.session.updateSharingGroup(sharingGroupUUID: sharingGroupUUID, newSharingGroupName: newSharingGroupName)
    
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, sharingGroupOperationExpected: true) else {
            XCTFail()
            return
        }
    
        guard let fileIndex = getFileIndex() else {
            XCTFail()
            return
        }
    
        let filter = fileIndex.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard filter.count == 1 else {
            XCTFail()
            return
        }
    
        XCTAssert(filter[0].sharingGroupName == newSharingGroupName)
    
        let filter2 = SyncServer.session.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filter2.count == 1 else {
            XCTFail()
            return
        }
    
        XCTAssert(filter2[0].sharingGroupName == newSharingGroupName)

        assertUploadTrackersAreReset()
    }
    
    func testThatChangingSharingGroupNameWorks() {
        changeSharingGroupName()
    }
    
    func testThatChangingSharingGroupNameTwiceGivesSecondNameWorks() {
        changeSharingGroupName(twice: true)
    }
    
    // MARK: Removing current user from sharing group
    
    func testRemoveUserFromSharingGroupWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        SyncServer.session.eventsDesired = [.syncDone, .sharingGroupUploadOperationCompleted]
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .sharingGroupUploadOperationCompleted:
                expectation2.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // Need to make sure the sharing groups have marked the user as removed: a) using file index, and b) in local persistent store.
        
        guard let fileIndex = getFileIndex() else {
            XCTFail()
            return
        }
    
        let filter = fileIndex.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard filter.count == 0 else {
            XCTFail()
            return
        }
        
        let filter2 = SyncServer.session.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filter2.count == 0 else {
            XCTFail()
            return
        }
        
        // So that we have at least one sharing group when the test ends.
        createSharingGroupUsingSyncWorks(name: nil)
    }
    
    // Remove user 2x without calling sync fails.
    func testRemoveUserFromSharingGroupTwiceSuccessivelyFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        try! SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
        do {
            try SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
            XCTFail()
        } catch {
        }
    }
    
    // Remove the user + sync; remove the user: Fails.
    func testRemoveUserFromSharingGroupTwiceWithSyncFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        SyncServer.session.eventsDesired = [.syncDone]
        let expectation1 = self.expectation(description: "test1")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        do {
            try SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
            XCTFail()
        } catch {
        }
        
        createSharingGroupUsingSyncWorks(name: nil)
    }
    
    func testUploadToARemovedSharingGroupFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
    
        SyncServer.session.eventsDesired = [.syncDone, .sharingGroupUploadOperationCompleted]
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
    
            case .sharingGroupUploadOperationCompleted:
                expectation2.fulfill()
    
            default:
                XCTFail()
            }
        }
    
        try! SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroupUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
    
        waitForExpectations(timeout: 20.0, handler: nil)
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        
        let fileUUID = UUID().uuidString

        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            XCTFail()
        } catch {
        }
    }
    
    // Returns list of sharing group UUID's.
    func getMultipleSharingGroups(numberNeeded: Int) -> [String]? {
        var sharingGroups = SyncServer.session.sharingGroups
        
        while numberNeeded < sharingGroups.count {
            guard let _ =  createSharingGroup() else {
                XCTFail()
                return nil
            }
            
            sharingGroups = SyncServer.session.sharingGroups
        }
        
        return sharingGroups.map {$0.sharingGroupUUID}
    }
    
    /*
        What happens if: With one sharing group, you do a sync operation. Then, the app crashes without completing the sync, say with some ongoing uploads or downloads. And you try to do a sync with another sharing group. The issue here I think is that the sync has stopped with one sharing group and will have to be restarted. A simulation of this could be:
        1) Upload 2 files to sharing group 1. Sync.
        2) Stop sync.
        3) Upload a file to sharing group 2. Sync.
        4) Resume sync on sharing group 1. Sync.
        Make sure all works appropriately.
    */
    func testResumeSyncAfterStoppingWorks() {
        guard let sharingGroupUUIDs = getMultipleSharingGroups(numberNeeded: 2) else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID1 = sharingGroupUUIDs[0]
        let sharingGroupUUID2 = sharingGroupUUIDs[1]
        
        // Step 1
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        let attr1 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID1, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID1, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .singleFileUploadComplete:
                // Step 2
                SyncServer.session.stopSync()
                expectation2.fulfill()

            default:
                XCTFail()
            }
        }

        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID1)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // Step 3
        guard let _ = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID2) else {
            XCTFail()
            return
        }

        // Step 4
        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]
        
        let expectation3 = self.expectation(description: "test3")
        let expectation4 = self.expectation(description: "test4")
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                expectation3.fulfill()
                
            case .singleFileUploadComplete (let attr):
                // Make sure this is the second file.
                XCTAssert(attr.fileUUID == attr2.fileUUID)
                expectation4.fulfill()

            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID2)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /*
        1) Upload file to sharing group1, sync
        2) Upload two files to sharing group2, sync.
    */
    func testMultipleSharingGroupUploadWorks() {
        guard let sharingGroupUUIDs = getMultipleSharingGroups(numberNeeded: 2) else {
            XCTFail()
            return
        }
    
        let sharingGroupUUID1 = sharingGroupUUIDs[0]
        let sharingGroupUUID2 = sharingGroupUUIDs[1]

        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        
        var numberUploads = 0
        let attr1 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID1, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID2, mimeType: .text)
        let attr3 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID2, mimeType: .text)

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                if numberUploads == 3 {
                    expectation1.fulfill()
                }
                
            case .singleFileUploadComplete (let attr):
                numberUploads += 1
                if numberUploads <= 3 {
                    switch numberUploads {
                    case 1:
                        XCTAssert(attr1.fileUUID == attr.fileUUID)
                        XCTAssert(attr1.sharingGroupUUID == attr.sharingGroupUUID)
                    case 2, 3:
                        XCTAssert(attr2.fileUUID == attr.fileUUID || attr3.fileUUID == attr.fileUUID)
                        XCTAssert(attr1.sharingGroupUUID == attr.sharingGroupUUID)
                    default:
                        XCTFail()
                    }
                }
                expectation2.fulfill()

            default:
                XCTFail()
            }
        }

        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID1)
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr3)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID2)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    // Error case: Upload a fileUUID that's in one sharing group to a second sharing group.
    func testErrorWhenUploadSameFileUUIDToMultipleSharingGroups() {
        guard let sharingGroupUUIDs = getMultipleSharingGroups(numberNeeded: 2) else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID1 = sharingGroupUUIDs[0]
        let sharingGroupUUID2 = sharingGroupUUIDs[1]
        
        guard let (url, attr1) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID1) else {
            XCTFail()
            return
        }
        
        let attr2 = SyncAttributes(fileUUID: attr1.fileUUID, sharingGroupUUID: sharingGroupUUID2, mimeType: .text)

        do {
            try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
            XCTFail()
        } catch {
        }
    }
    
    // One download available in each of two sharing groups.
    func testDownloadCases() {
        guard let sharingGroupUUIDs = getMultipleSharingGroups(numberNeeded: 2) else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID1 = sharingGroupUUIDs[0]
        let sharingGroupUUID2 = sharingGroupUUIDs[1]
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        // group1
        guard let masterVersion1 = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID1) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text,  sharingGroupUUID: sharingGroupUUID1, fileUUID: fileUUID1, serverMasterVersion: masterVersion1) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion1, sharingGroupUUID: sharingGroupUUID1, expectedNumberUploads: 1)
        
        // group2
        guard let masterVersion2 = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID2) else {
            XCTFail()
            return
        }
        
        let fileUUID2 = UUID().uuidString
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text,  sharingGroupUUID: sharingGroupUUID2, fileUUID: fileUUID2, serverMasterVersion: masterVersion2) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion2, sharingGroupUUID: sharingGroupUUID2, expectedNumberUploads: 1)

        SyncServer.session.eventsDesired = [.syncDone]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        
        var numberSyncDone = 0
        var numberDownloadsDone = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                numberSyncDone += 1
                if numberSyncDone == 2 {
                    expectation1.fulfill()
                }

            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { download in
            numberDownloadsDone += 1
            
            switch numberDownloadsDone {
            case 1:
                if download.count == 1 {
                    XCTAssert(download[0].attr.fileUUID == fileUUID1)
                }
                else {
                    XCTFail()
                }
            case 2:
                if download.count == 1 {
                    XCTAssert(download[0].attr.fileUUID == fileUUID2)
                }
                else {
                    XCTFail()
                }
            default:
                XCTFail()
            }
            
            if numberDownloadsDone == 2 {
                expectation2.fulfill()
            }
        }

        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID2)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Upload and download sync cases:
        group1: no downloads, no uploads
        group2: Only download available
        group3: Only upload available.
        group4: Both upload and download available.
    */
    func testUploadAndDownloadCases() {
        guard let sharingGroupUUIDs = getMultipleSharingGroups(numberNeeded: 4) else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID1 = sharingGroupUUIDs[0]
        let sharingGroupUUID2 = sharingGroupUUIDs[1]
        let sharingGroupUUID3 = sharingGroupUUIDs[2]
        let sharingGroupUUID4 = sharingGroupUUIDs[3]

        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!

        // group2
        guard let masterVersion_group2 = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID2) else {
            XCTFail()
            return
        }
        
        let fileUUID_group2 = UUID().uuidString

        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text,  sharingGroupUUID: sharingGroupUUID2, fileUUID: fileUUID_group2, serverMasterVersion: masterVersion_group2) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion_group2, sharingGroupUUID: sharingGroupUUID2, expectedNumberUploads: 1)
        
        // group3
        let attrGroup3 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID3, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attrGroup3)
        
        // group4
        let fileUUID_group4 = UUID().uuidString

        guard let masterVersion_group4 = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID4) else {
            XCTFail()
            return
        }
        
        guard let (_, _) = uploadFile(fileURL:url as URL, mimeType: .text,  sharingGroupUUID: sharingGroupUUID4, fileUUID: fileUUID_group4, serverMasterVersion: masterVersion_group4) else {
            return
        }

        doneUploads(masterVersion: masterVersion_group4, sharingGroupUUID: sharingGroupUUID4, expectedNumberUploads: 1)

        let attrGroup4 = SyncAttributes(fileUUID: UUID().uuidString, sharingGroupUUID: sharingGroupUUID4, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attrGroup4)
        
        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]
        
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        let expectation3 = self.expectation(description: "test2")

        var numberSyncDone = 0
        var numberDownloadsDone = 0
        var numberUploadsDone = 0

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                numberSyncDone += 1
                if numberSyncDone == 4 {
                    expectation1.fulfill()
                }
                
            case .singleFileUploadComplete (let attr):
                numberUploadsDone += 1
                
                switch numberUploadsDone {
                case 1:
                    XCTAssert(attr.fileUUID == attrGroup3.fileUUID)
                case 2:
                    XCTAssert(attr.fileUUID == attrGroup4.fileUUID)
                default:
                    XCTFail()
                }
                
                if numberUploadsDone == 2 {
                    expectation2.fulfill()
                }

            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { download in
            numberDownloadsDone += 1
            
            switch numberDownloadsDone {
            case 1:
                if download.count == 1 {
                    XCTAssert(download[0].attr.fileUUID == fileUUID_group2)
                }
                else {
                    XCTFail()
                }
            case 2:
                if download.count == 1 {
                    XCTAssert(download[0].attr.fileUUID == fileUUID_group4)
                }
                else {
                    XCTFail()
                }
            default:
                XCTFail()
            }
            
            if numberDownloadsDone == 2 {
                expectation3.fulfill()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID2)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID3)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID4)

        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
