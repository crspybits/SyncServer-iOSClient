//
//  SyncServerUser_Sharing.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 4/9/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class SyncServerUser_Sharing: TestCase {
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testGetSharingInvitationInfoWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let permission:Permission = .read
        let allowSharingAcceptance = true
        var sharingInvitionUUID:String!
        
        let create = self.expectation(description: "CreateSharingInvitation")

        SyncServerUser.session.createSharingInvitation(withPermission: permission, sharingGroupUUID: sharingGroup.sharingGroupUUID, numberAcceptors: 1, allowSharingAcceptance: allowSharingAcceptance) { inviteCode, error in
            XCTAssert(inviteCode != nil)
            XCTAssert(error == nil)
            sharingInvitionUUID = inviteCode
            create.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        guard sharingInvitionUUID != nil else {
            XCTFail()
            return
        }
        
        let getInfo = self.expectation(description: "GetSharingInvitationInfo")
        
        SyncServerUser.session.getSharingInvitationInfo(invitationCode: sharingInvitionUUID) { info, error in
            if let info = info, error == nil {
                switch info {
                case .invitation(permission: let perm, allowSocialAcceptance: let allow):
                    XCTAssert(allowSharingAcceptance == allow)
                    XCTAssert(permission == perm)
                case .noInvitationFound:
                    XCTFail()
                }
            }
            else {
                XCTFail()
            }
            
            getInfo.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testGetSharingInvitationInfoForBadSharingInviteFails() {
        let sharingInvitionUUID = UUID().uuidString

        let getInfo = self.expectation(description: "GetSharingInvitationInfo")
        
        SyncServerUser.session.getSharingInvitationInfo(invitationCode: sharingInvitionUUID) { info, error in
            if let info = info, error == nil {
                switch info {
                case .invitation:
                    XCTFail()
                case .noInvitationFound:
                    break
                }
            }
            else {
                XCTFail()
            }
            
            getInfo.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
