//
//  SyncServerSharing_Tests.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 8/24/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class SyncServerSharing_Tests: TestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateSharingGroupWorksWithNoNameWorks() {
        var sgid:SharingGroupId!
        
        let expectation = self.expectation(description: "test")

        SyncServerSharing.session.createSharingGroup() { response in
            switch response {
            case .success(let sharingGroupId):
                sgid = sharingGroupId
        
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)

        guard sgid != nil, let fileIndexResult = self.getFileIndex(sharingGroupId: sgid),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }

        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sgid}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == nil,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testCreateSharingGroupWorksWithNameWorks() {
        var sgid:SharingGroupId!
        let sharingGroupName = UUID().uuidString
        
        let expectation = self.expectation(description: "test")

        SyncServerSharing.session.createSharingGroup(sharingGroupName: sharingGroupName) { response in
            switch response {
            case .success(let sharingGroupId):
                sgid = sharingGroupId
        
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)

        guard sgid != nil, let fileIndexResult = self.getFileIndex(sharingGroupId: sgid),
            let _ = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }

        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sgid}
        guard filteredResult.count == 1, filteredResult[0].sharingGroupName == sharingGroupName,
            filteredResult[0].sharingGroupUsers.count == 1 else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroupWorks() {
        let sharingGroupName = UUID().uuidString

        guard let sharingGroups = SyncServerUser.session.sharingGroups,
            sharingGroups.count > 0,
            let sharingGroupId = sharingGroups[0].sharingGroupId else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "test")

        SyncServerSharing.session.updateSharingGroup(sharingGroupId: sharingGroupId, sharingGroupName: sharingGroupName) { error in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        guard let fileIndexResult = self.getFileIndex(sharingGroupId: sharingGroupId),
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
    
    func testRemoveSharingGroupWorks() {
        var sgid:SharingGroupId!
        
        let expectation1 = self.expectation(description: "test")

        SyncServerSharing.session.createSharingGroup() { response in
            switch response {
            case .success(let sharingGroupId):
                sgid = sharingGroupId
        
            case .error:
                XCTFail()
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)

        let expectation2 = self.expectation(description: "test")

        SyncServerSharing.session.removeSharingGroup(sharingGroupId: sgid) { error in
            XCTAssert(error == nil)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        guard let fileIndexResult = self.getFileIndex(sharingGroupId: nil) else {
            XCTFail()
            return
        }

        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sgid}
        guard filteredResult.count == 0 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveUserFromSharingGroupWorks() {
        var sgid:SharingGroupId!
        
        let expectation1 = self.expectation(description: "test")

        SyncServerSharing.session.createSharingGroup() { response in
            switch response {
            case .success(let sharingGroupId):
                sgid = sharingGroupId
        
            case .error:
                XCTFail()
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        let expectation2 = self.expectation(description: "test")

        SyncServerSharing.session.removeUserFromSharingGroup(sharingGroupId: sgid) { error in
            XCTAssert(error == nil)
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        guard let fileIndexResult = self.getFileIndex(sharingGroupId: nil) else {
            XCTFail()
            return
        }

        let filteredResult = fileIndexResult.sharingGroups.filter{$0.sharingGroupId == sgid}
        guard filteredResult.count == 0 else {
            XCTFail()
            return
        }
    }
}
