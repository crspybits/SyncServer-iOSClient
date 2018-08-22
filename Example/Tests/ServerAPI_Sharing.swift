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
}
