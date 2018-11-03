//
//  Client_SyncManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/26/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class Client_SyncManager: TestCase {    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStartWithNoFilesOnServer() {
        guard let sharingGroup = getFirstSharingGroup()else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let expectation = self.expectation(description: "next")

        syncServerEventOccurred = { event in
            XCTFail()
        }
        
        SyncManager.session.start(sharingGroupUUID: sharingGroupUUID) { (error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testStartWithOneUploadedFileOnServer() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        uploadAndDownloadOneFileUsingStart(sharingGroupUUID: sharingGroupUUID)
    }
    
    func downloadTwoFilesUsingStart(file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt, sharingGroupUUID: String, singleFileDownloaded:(()->())? = nil, completion:(()->())? = nil) {
        let expectedFiles = [file1, file2]
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        let expectation = self.expectation(description: "start")
        let file1Exp = self.expectation(description: "file1")
        let file2Exp = self.expectation(description: "file2")

        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url, let contentsChanged) = group[0].type {
                XCTAssert(!contentsChanged)
                
                let attr = group[0].attr
                singleFileDownloaded?()
                
                downloadCount += 1
                XCTAssert(downloadCount <= 2)
                
                if file1.fileUUID == attr.fileUUID {
                    XCTAssert(self.filesHaveSameContents(url1: file1.localURL, url2: url as URL))
                    file1Exp.fulfill()
                }
                
                if file2.fileUUID == attr.fileUUID {
                    XCTAssert(self.filesHaveSameContents(url1: file2.localURL, url2: url as URL))
                    file2Exp.fulfill()
                }
            }
            else {
                XCTFail()
            }
        }
        
        SyncManager.session.start(sharingGroupUUID: sharingGroupUUID) { (error) in
            XCTAssert(error == nil, "\(String(describing: error))")
            
            XCTAssert(downloadCount == 2)
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                let entries = DirectoryEntry.fetchAll()
                XCTAssert(entries.count == expectedFiles.count)

                for file in expectedFiles {
                    let entriesResult = entries.filter { $0.fileUUID == file.fileUUID &&
                        $0.fileVersion == file.fileVersion
                    }
                    XCTAssert(entriesResult.count == 1)
                }
            }
            
            completion?()
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 60.0, handler: nil)
    }
    
    func uploadTwoFiles(sharingGroupUUID: String) -> (file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt)? {
    
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file1 = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        guard let file2 = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        return (file1, file2, masterVersion)
    }
    
    func testStartWithTwoUploadedFilesOnServer() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (file1, file2, masterVersion) = uploadTwoFiles(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    // Simulation of master version change on server-- by changing it locally.
    func testWhereMasterVersionChangesMidwayThroughTwoDownloads() {
        var numberDownloads = 0
        
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
 
        guard let (file1, file2, masterVersion) = uploadTwoFiles(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
    
        let singleFileDownload = {
            numberDownloads += 1
            if numberDownloads == 1 {
                // This is fake: It would be conceptually better to upload a file here but that's a bit of a pain the way I have it setup in testing.
                guard self.decrementMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
                    XCTFail()
                    return
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch {
                        XCTFail()
                    }
                }
            }
        }
        
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, singleFileDownloaded: singleFileDownload)
    }
}
