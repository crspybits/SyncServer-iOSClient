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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateSharingInvitation() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "CreateSharingInvitation")
        
        ServerAPI.session.createSharingInvitation(withPermission: .read, sharingGroupId: sharingGroupId) { (sharingInvitationUUID, error) in
            XCTAssert(error == nil)
            XCTAssert(sharingInvitationUUID != nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testThatSameUserCannotRedeemInvitation() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupId = sharingGroup.sharingGroupId else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "SharingInvitation")

        ServerAPI.session.createSharingInvitation(withPermission: .read, sharingGroupId: sharingGroupId) { (sharingInvitationUUID, error) in
            XCTAssert(error == nil)
            XCTAssert(sharingInvitationUUID != nil)
            ServerAPI.session.redeemSharingInvitation(sharingInvitationUUID: sharingInvitationUUID!, cloudFolderName: self.cloudFolderName) { accessToken, sharingGroupId, error in
                XCTAssert(error != nil)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func testCreateNewSharingGroupWithoutName() {
        guard let sharingGroupId = createSharingGroup(sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult = getFileIndex(sharingGroupId: sharingGroupId),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sharingGroupId}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == nil,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testCreateNewSharingGroupWithName() {
        let sharingGroupName = "Foobar"
        guard let sharingGroupId = createSharingGroup(sharingGroupName: sharingGroupName) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult = getFileIndex(sharingGroupId: sharingGroupId),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sharingGroupId}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == sharingGroupName,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroup() {
        let newSharingGroupName = UUID().uuidString

        guard let fileIndexResult = getFileIndex(sharingGroupId: nil),
            fileIndexResult.sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = fileIndexResult.sharingGroups[0]
        
        if let _ = updateSharingGroup(sharingGroupId: sharingGroup.sharingGroupId!, masterVersion: sharingGroup.masterVersion!, sharingGroupName: newSharingGroupName) {
            XCTFail()
            return
        }
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupId: sharingGroup.sharingGroupId!),
            let _ = fileIndexResult2.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult2 = fileIndexResult2.sharingGroups.filter{$0.sharingGroupId == sharingGroup.sharingGroupId!}
        guard filteredResult2.count == 1 else {
            XCTFail()
            return
        }
        
        let result = filteredResult2[0]
        
        XCTAssert(result.sharingGroupName == newSharingGroupName, "result.sharingGroupName: \(String(describing: result.sharingGroupName)); newSharingGroupName: \(newSharingGroupName)")
        XCTAssert(result.sharingGroupUsers.count == 1)
    }
    
    func testRemoveSharingGroupWorks() {
        guard let fileIndexResult = getFileIndex(sharingGroupId: nil),
            fileIndexResult.sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = fileIndexResult.sharingGroups[0]
        
        if let _ = removeSharingGroup(sharingGroupId: sharingGroup.sharingGroupId!, masterVersion: sharingGroup.masterVersion!) {
            XCTFail()
            return
        }
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupId: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult2 = fileIndexResult2.sharingGroups.filter{$0.sharingGroupId == sharingGroup.sharingGroupId!}
        guard filteredResult2.count == 0 else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndexResult.sharingGroups.count - 1 == fileIndexResult2.sharingGroups.count)
    }
}
