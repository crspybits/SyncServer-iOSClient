//
//  FileIndex.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/2/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SyncServer_Shared

class ServerAPI_FileIndex: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    @discardableResult
    func getFileIndexAndMasterVersion(sharingGroupUUID: String) -> ServerAPI.IndexResult?  {
        var indexResult:ServerAPI.IndexResult?
        
        let expectation = self.expectation(description: "file index")
        
        ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
            switch response {
            case .success(let result):
                indexResult = result
            case .error(let error):
                XCTFail("\(error)")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return indexResult
    }
    
    func testFileIndex() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID)
    }
    
    // Added this due some debugging of a problem I was doing on 1/16/18.
    func testFileIndexFollowedByUpload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let result = getFileIndexAndMasterVersion(sharingGroupUUID: sharingGroupUUID),
            let masterVersion = result.masterVersion else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion)
    }
}
