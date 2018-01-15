//
//  Client_SyncServer_MultiVersionFiles.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 1/11/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest

class Client_SyncServer_MultiVersionFiles: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Multi-version files
    
    // 1) queue for upload the same file several times.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    func testExample() {
    }
    
    // 2) File download various file versions
    
    // 3) Upload deletion some higher numbered file version-- will have to upload the same file several times first.
    
    // 4) Download deletion of some higher numbered file version.
    
    // MARK: Conflict resolution
    
    // 5) Deletion conflict: a file is being download deleted, but there is a pending upload for the same file.
    
    // 6) A file is being download deleted, and there is a pending upload deletion for the same file.
    
    // 7) A file is being downloaded, and there is a file upload for the same file.
    
    // 8) A file is being downloaded, and there is an upload deletion pending for the same file.
}
