//
//  Client_SyncServer_Misc.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 7/19/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_Misc: XCTestCase {
        
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSharingGroupsSetToNilWorks() {
        SyncServerUser.session.sharingGroups = nil
        XCTAssert(SyncServerUser.session.sharingGroups == nil)
    }
    
    func testSharingGroupIdsSetToValidListWorks() {
        let sgu1 = SharingGroupUser(json: [:])!
        sgu1.name = "Chris"
        sgu1.userId = 2
        let sg1 = SharingGroup(json: [:])!
        sg1.deleted = false
        sg1.masterVersion = 1
        sg1.permission = .admin
        sg1.sharingGroupUUID = UUID().uuidString
        sg1.sharingGroupUsers = [sgu1]
    
        SyncServerUser.session.sharingGroups = [sg1]
        
        guard let sgs = SyncServerUser.session.sharingGroups, sgs.count == 1 else {
            XCTFail()
            return
        }
        
        let result1 = sgs[0]
        XCTAssert(result1.deleted == sg1.deleted)
        XCTAssert(result1.masterVersion == sg1.masterVersion)
        XCTAssert(result1.permission == sg1.permission)
        XCTAssert(result1.sharingGroupUUID == sg1.sharingGroupUUID)

        guard let sgus = result1.sharingGroupUsers, sgus.count == 1 else {
            XCTFail()
            return
        }
        
        let result2 = sgus[0]
        XCTAssert(result2.name == sgu1.name)
        XCTAssert(result2.userId == sgu1.userId)
    }
}
