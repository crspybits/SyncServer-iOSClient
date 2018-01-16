//
//  Client_SyncServer_MultiVersionFiles.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 1/11/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_MultiVersionFiles: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Multi-version files
    
    // uploads text files.
    func sequentialUploadNextVersion(fileUUID:String, expectedVersion: FileVersionInt, fileURL:SMRelativeLocalURL? = nil) {
        let (url, attr) = uploadSingleFileUsingSync(fileUUID: fileUUID, fileURL:fileURL)
        
        getFileIndex(expectedFiles: [(fileUUID: attr.fileUUID, fileSize: nil)])
        
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
            guard let dirEntry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(dirEntry.fileVersion == expectedVersion)
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: attr.fileUUID, mimeType: nil, cloudFolderName: nil, deviceUUID: nil, appMetaData: nil, fileVersion: expectedVersion)
        onlyDownloadFile(comparisonFileURL: url, file: file, masterVersion: masterVersion)
    }
    
    // 1a) upload the same file UUID several times, sequentially. i.e., do a sync after queuing it each time.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    func testUploadVersion1() {
        let fileUUID = UUID().uuidString
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 0)
        
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 1, fileURL: url2)
        
        let url3 = SMRelativeLocalURL(withRelativePath: "UploadMe4.txt", toBaseURLType: .mainBundle)!
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 2, fileURL: url3)
    }
    
    // 1b) queue for upload the same file several times, concurrently. Don't do a sync until queuing each one.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    
    // 2) File download various file versions
    
    // 3) Upload deletion some higher numbered file version-- will have to upload the same file several times first.
    
    // 4) Download deletion of some higher numbered file version.
    
    // MARK: Conflict resolution
    
    // 5) Deletion conflict: a file is being download deleted, but there is a pending upload for the same file.
    
    // 6) A file is being download deleted, and there is a pending upload deletion for the same file.
    
    // 7) A file is being downloaded, and there is a file upload for the same file.
    
    // 8) A file is being downloaded, and there is an upload deletion pending for the same file.
    
    // What happens when a file locally marked as deleted gets downloaded again, becuase someone else did an upload undeletion? Have we covered that case?
}
