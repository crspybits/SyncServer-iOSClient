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
    
    func testSharingGroupIdsSetToNilWorks() {
        SyncServerUser.session.sharingGroupIds = nil
        XCTAssert(SyncServerUser.session.sharingGroupIds == nil)
    }
    
    func testSharingGroupIdsSetToValidListWorks() {
        let sharingGroupIds:[SharingGroupId] = [1, 2, 3]
        SyncServerUser.session.sharingGroupIds = sharingGroupIds
        XCTAssert(SyncServerUser.session.sharingGroupIds == sharingGroupIds)
    }
}
