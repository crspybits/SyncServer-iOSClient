//
//  Client_SyncServer_Sync.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/6/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation

class Client_SyncServer_Sync: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        SyncServer.session.eventsDesired = .defaults
        super.tearDown()
    }

    // 3/26/17; I have now turned on "-com.apple.CoreData.ConcurrencyDebug 1" (see http://stackoverflow.com/questions/31391838) as a strict measure to make sure I'm getting concurrency right with Core Data. I recently started having problems with this.
    
    func testThatSyncWithNoFilesResultsInSyncDone() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        SyncServer.session.eventsDesired = .all

        let syncStarted = self.expectation(description: "test1")
        let syncDone = self.expectation(description: "test2")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncStarted:
                syncStarted.fulfill()
                
            case .syncDone:
                syncDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [])

        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testThatDoingSyncTwiceWithNoFilesResultsInTwoSyncDones() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        SyncServer.session.eventsDesired = .all

        let syncStarted1 = self.expectation(description: "test1")
        let syncStarted2 = self.expectation(description: "test2")
        let syncDone1 = self.expectation(description: "test3")
        let syncDone2 = self.expectation(description: "test4")
        let syncDelayed = self.expectation(description: "test5")

        var syncDoneCount = 0
        var syncStartedCount = 0

        syncServerEventOccurred = {event in
            switch event {
            case .syncStarted:
                syncStartedCount += 1
                switch syncStartedCount {
                case 1:
                    syncStarted1.fulfill()
                    
                case 2:
                    syncStarted2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            case .syncDone:
                syncDoneCount += 1
                switch syncDoneCount {
                case 1:
                    syncDone1.fulfill()
                    
                case 2:
                    syncDone2.fulfill()
                    
                default:
                    XCTFail()
                }
                
            case .syncDelayed:
                syncDelayed.fulfill()
                
            default:
                XCTFail("\(event)")
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [])

        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    // TODO: *0* Do a sync with no uploads pending, but pending downloads.
}
