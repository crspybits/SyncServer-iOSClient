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

class Client_SyncServer_Misc: TestCase {
        
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUpdateSharingGroups() {
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        let sharingGroups = SyncServer.session.sharingGroups
        guard sharingGroups.count > 0 else {
            XCTFail()
            return
        }
    }
    
    func testDeletionOfSharingGroupRemovesItFromClientSharingGroups() {
        // Create new sharing group
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        // Update sharing groups-- make sure it's there.
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        let newSharingGroupList = SyncServer.session.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard newSharingGroupList.count == 1 else {
            XCTFail()
            return
        }
        
        var masterVersion: MasterVersionInt!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
            masterVersion = sharingEntry.masterVersion
        }
        
        guard masterVersion != nil else {
            XCTFail()
            return
        }
        
        // Delete that sharing group.
        if let _ = removeSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: masterVersion) {
            XCTFail()
            return
        }
        
        // Update sharing groups-- make sure it's gone.
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        let newSharingGroupList2 = SyncServer.session.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        guard newSharingGroupList2.count == 0 else {
            XCTFail()
            return
        }
    }
}
