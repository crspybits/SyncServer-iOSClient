//
//  ServerAPI_GetUploads.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/18/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer

class ServerAPI_GetUploads: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGetUploads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let expectation = self.expectation(description: "GetUploads")
        
        ServerAPI.session.getUploads(sharingGroupUUID: sharingGroupUUID) { (uploads, error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
