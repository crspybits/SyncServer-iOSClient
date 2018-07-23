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
        
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStartWithNoFilesOnServer() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "next")

        syncServerEventOccurred = { event in
            XCTFail()
        }
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testStartWithOneUploadedFileOnServer() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        uploadAndDownloadOneFileUsingStart(sharingGroupId: sharingGroupId)
    }
    
    func downloadTwoFilesUsingStart(file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt, sharingGroupId: SharingGroupId, singleFileDownloaded:(()->())? = nil, completion:(()->())? = nil) {
        let expectedFiles = [file1, file2]
        
        doneUploads(masterVersion: masterVersion, sharingGroupId: sharingGroupId, expectedNumberUploads: 2)
        
        let expectation = self.expectation(description: "start")
        let file1Exp = self.expectation(description: "file1")
        let file2Exp = self.expectation(description: "file2")

        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url) = group[0].type {
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
        
        SyncManager.session.start(sharingGroupId: sharingGroupId) { (error) in
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
    
    func uploadTwoFiles(sharingGroupId: SharingGroupId) -> (file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt)? {
    
        guard let masterVersion = getMasterVersion(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return nil
        }

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file1) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        guard let (_, file2) = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupId: sharingGroupId, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        return (file1, file2, masterVersion)
    }
    
    func testStartWithTwoUploadedFilesOnServer() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        guard let (file1, file2, masterVersion) = uploadTwoFiles(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
    }
    
    // Simulation of master version change on server-- by changing it locally.
    func testWhereMasterVersionChangesMidwayThroughTwoDownloads() {
        var numberDownloads = 0
        
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
 
        guard let (file1, file2, masterVersion) = uploadTwoFiles(sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        let singleFileDownload = {
            numberDownloads += 1
            if numberDownloads == 1 {
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // This is fake: It would be conceptually better to upload a file here but that's a bit of a pain the way I have it setup in testing.
                    Singleton.get().masterVersion = Singleton.get().masterVersion - 1
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch {
                        XCTFail()
                    }
                }
            }
        }
        
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion, sharingGroupId: sharingGroupId, singleFileDownloaded: singleFileDownload)
    }
}
