//
//  ServerAPI_GetSharingGroupIds.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 7/16/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SyncServer_Shared

class ServerAPI_GetSharingGroupIds: TestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /*
    @discardableResult
    func getSharingGroups() -> [SharingGroupId]?  {
        var result:[SharingGroupId]?
        
        let expectation = self.expectation(description: "get sharing groups)
        
        ServerAPI.session
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            XCTAssert(error == nil)
            XCTAssert(masterVersion! >= 0)
            
            if let fileIndex = fileIndex, let masterVersion = masterVersion, masterVersion >= 0 {
                result = (fileIndex, masterVersion)
            }
            else {
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return result
    }
    */
    
    func testExample() {

    }
}
