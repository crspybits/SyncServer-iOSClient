//
//  ServerAPI_Sharing.swift
//  SyncServer
//
//  Created by Christopher Prince on 4/16/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerAPI_Sharing: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateSharingInvitation() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let expectation = self.expectation(description: "CreateSharingInvitation")
        
        ServerAPI.session.createSharingInvitation(withPermission: .read, sharingGroupUUID: sharingGroupUUID) { (sharingInvitationUUID, error) in
            XCTAssert(error == nil)
            XCTAssert(sharingInvitationUUID != nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testThatSameUserCannotRedeemInvitation() {
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
        
        guard sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroups[0].sharingGroupUUID
        
        let expectation = self.expectation(description: "SharingInvitation")

        ServerAPI.session.createSharingInvitation(withPermission: .read, sharingGroupUUID: sharingGroupUUID) { (sharingInvitationUUID, error) in
            guard error == nil, sharingInvitationUUID != nil else {
                XCTFail()
                return
            }

            ServerAPI.session.redeemSharingInvitation(sharingInvitationUUID: sharingInvitationUUID!, cloudFolderName: self.cloudFolderName) { accessToken, sharingGroupId, error in
                XCTAssert(error != nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func testCreateNewSharingGroupWithoutName() {
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == nil,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testCreateNewSharingGroupWithName() {
        let sharingGroupName = "Foobar"
        let sharingGroupUUID = UUID().uuidString

        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: sharingGroupName) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == sharingGroupName,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroup() {
        let newSharingGroupName = UUID().uuidString

        guard let fileIndexResult = getFileIndex(sharingGroupUUID: nil),
            fileIndexResult.sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = fileIndexResult.sharingGroups[0]
        
        if let _ = updateSharingGroup(sharingGroupUUID: sharingGroup.sharingGroupUUID!, masterVersion: sharingGroup.masterVersion!, sharingGroupName: newSharingGroupName) {
            XCTFail()
            return
        }
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupUUID: sharingGroup.sharingGroupUUID!),
            let _ = fileIndexResult2.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult2 = fileIndexResult2.sharingGroups.filter{$0.sharingGroupUUID == sharingGroup.sharingGroupUUID!}
        guard filteredResult2.count == 1 else {
            XCTFail()
            return
        }
        
        let result = filteredResult2[0]
        
        XCTAssert(result.sharingGroupName == newSharingGroupName, "result.sharingGroupName: \(String(describing: result.sharingGroupName)); newSharingGroupName: \(newSharingGroupName)")
        XCTAssert(result.sharingGroupUsers.count == 1)
    }
    
    func testRemoveSharingGroupWorks() {
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: nil),
            fileIndexResult.sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = fileIndexResult.sharingGroups[0]
        
        if let _ = removeSharingGroup(sharingGroupUUID: sharingGroup.sharingGroupUUID!, masterVersion: sharingGroup.masterVersion!) {
            XCTFail()
            return
        }
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult2 = fileIndexResult2.sharingGroups.filter{$0.sharingGroupUUID == sharingGroup.sharingGroupUUID!}
        guard filteredResult2.count == 0 else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndexResult.sharingGroups.count - 1 == fileIndexResult2.sharingGroups.count)
    }

    func testRemoveUserFromSharingGroupWorks() {
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult1 = getFileIndex(sharingGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult1 = fileIndexResult1.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filteredResult1.count == 1 else {
            XCTFail()
            return
        }
        
        if let _ = removeUserFromSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: 0) {
            XCTFail()
            return
        }
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult2 = fileIndexResult2.sharingGroups.filter{$0.sharingGroupUUID == sharingGroupUUID}
        guard filteredResult2.count == 0 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWithAFileWorks() {
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult1 = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex1 = fileIndexResult1.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult1 = fileIndex1.filter{$0.fileUUID == attr.fileUUID}
        guard filteredResult1.count == 1 else {
            XCTFail()
            return
        }
        
        if let _ = removeSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: fileIndexResult1.masterVersion!) {
            XCTFail()
            return
        }
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, errorExpected: true)
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult2.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        XCTAssert(filteredResult.count == 0)
    }
}
