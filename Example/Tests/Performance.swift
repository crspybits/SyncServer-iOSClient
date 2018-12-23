//
//  Performance.swift
//  SyncServer
//
//  Created by Christopher Prince on 5/21/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SyncServer_Shared

class Performance: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest(removeServerFiles: true, actualDeletion: false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func downloadNFiles(_ N:UInt, fileName: String, fileExtension:String, mimeType:MimeType, sharingGroupUUID: String) {
        // First upload N files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        
        for _ in 1...N {
            let fileUUID = UUID().uuidString

            guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
                return
            }
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: Int64(N))
        
        let expectation = self.expectation(description: "downloadNFiles")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0

        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                downloadCount += 1
                XCTAssert(downloadCount <= Int(N), "Current number of downloads: \(downloadCount)")
                if downloadCount >= N {
                    expectation.fulfill()
                }
            }
            else {
                XCTFail()
            }
        }
        
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        let done = self.expectation(description: "done")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: Double(N) * 30.0, handler: nil)
    }
    
    func test10SmallTextFileDownloads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadNFiles(10, fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func test10_120K_ImageFileDownloads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadNFiles(10, fileName: "CatBehaviors", fileExtension:"jpg", mimeType: .jpeg, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
 
    // 5/27/17; I've been having problems with large-ish downloads. E.g., See https://stackoverflow.com/questions/44224048/timeout-issue-when-downloading-from-aws-ec2-to-ios-app
    func test10SmallerImageFileDownloads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadNFiles(10, fileName: "SmallerCat", fileExtension:"jpg", mimeType: .jpeg, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func test10LargeImageFileDownloads() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadNFiles(10, fileName: "Cat", fileExtension:"jpg", mimeType: .jpeg, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func interspersedDownloadsOfSmallTextFile(_ N:Int, sharingGroupUUID: String) {
        for _ in 1...N {
            doASingleDownloadUsingSync(fileName: "UploadMe", fileExtension:"txt", mimeType: .text, sharingGroupUUID: sharingGroupUUID)
        }
    }
    
    // TODO: *0* Change this to not allow retries at the ServerAPI or networking level. i.e., so that it fails if a retry was to be required.
    func test10SmallTextFileDownloadsInterspersed() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        interspersedDownloadsOfSmallTextFile(10, sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func deleteNFiles(_ N:UInt, fileName: String, fileExtension:String, mimeType:MimeType) {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID

        // First upload N files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        
        var fileUUIDs = [String]()
        
        for _ in 1...N {
            let fileUUID = UUID().uuidString
            fileUUIDs.append(fileUUID)
            
            guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID:sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
                return
            }
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: Int64(N))
        
        for fileIndex in 0...N-1 {
            let fileUUID = fileUUIDs[Int(fileIndex)]

            let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
            uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
        }
        
        doneUploads(masterVersion: masterVersion+1, sharingGroupUUID: sharingGroupUUID, expectedNumberDeletions: N)
    }
    
    // Failed with `shouldSaveDownload` being nil, when run with others as a group.
    func test10Deletions() {
        deleteNFiles(10, fileName: "UploadMe", fileExtension:"txt", mimeType: .text)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func test25Deletions() {
        // 12/25/17; Previously I had this set to 50 deletions, but I run into a 504 HTTP response from the server, and I think it's from NGINX. See https://github.com/crspybits/SyncServerII/issues/48
        deleteNFiles(25, fileName: "UploadMe", fileExtension:"txt", mimeType: .text)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    // The reason for this test case is: https://github.com/crspybits/SyncServerII/issues/39
    // This test case did *not* reproduce the issue.
    func testFileIndexWhileDownloadingImages() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID

        
        // Goal-- to download 10 images using sync, and do FileIndex's (just using the ServerAPI) while those are going on.
        
        let N = 10
        let fileName = "Cat"
        let fileExtension = "jpg"
        let mimeType:MimeType = .jpeg

        // First upload N files.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        
        for _ in 1...N {
            let fileUUID = UUID().uuidString

            guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
                return
            }
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: Int64(N))
        
        let downloadExp = self.expectation(description: "download")
        let fileIndexExp = self.expectation(description: "fileIndex")
        
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        func recursiveFileIndex() {
            ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
                switch response {
                case .success:
                    if downloadCount < Int(N) {
                        DispatchQueue.global().async {
                            recursiveFileIndex()
                        }
                    }
                    else {
                        fileIndexExp.fulfill()
                    }
                case .error(let error):
                    XCTFail("\(error)")
                    fileIndexExp.fulfill()
                }
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                downloadCount += 1
                XCTAssert(downloadCount <= Int(N), "Current number of downloads: \(downloadCount)")
                if downloadCount >= N {
                    downloadExp.fulfill()
                }
            }
            else {
                XCTFail()
            }
        }
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        recursiveFileIndex()
        
        waitForExpectations(timeout: Double(N) * 30.0, handler: nil)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
}
