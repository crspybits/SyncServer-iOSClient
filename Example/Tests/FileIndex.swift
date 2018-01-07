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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    @discardableResult
    func getFileIndex() -> (fileIndex: [FileInfo], masterVersion:MasterVersionInt)?  {
        var result:(fileIndex: [FileInfo], masterVersion:MasterVersionInt)?
        
        let expectation = self.expectation(description: "file index")
        
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
    
    func testFileIndex() {
        getFileIndex()
    }
    
    // Added this due some debugging of a problem I was doing on 1/16/18.
    func testFileIndexFollowedByUpload() {
        guard let (_, masterVersion) = getFileIndex() else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        _ = uploadFile(fileURL:fileURL, mimeType: "text/plain", serverMasterVersion: masterVersion)
    }
}
