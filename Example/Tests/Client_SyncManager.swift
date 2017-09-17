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
        let expectation = self.expectation(description: "next")

        syncServerEventOccurred = { event in
            XCTFail()
        }
        
        SyncManager.session.start { (error) in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testStartWithOneUploadedFileOnServer() {
        uploadAndDownloadOneFileUsingStart()
    }
    
    func downloadTwoFilesUsingStart(file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt, singleFileDownloaded:(()->())? = nil, completion:(()->())? = nil) {
        let expectedFiles = [file1, file2]
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        let expectation = self.expectation(description: "start")
        let file1Exp = self.expectation(description: "file1")
        let file2Exp = self.expectation(description: "file2")

        var downloadCount = 0
        shouldSaveDownload = { url, attr in
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
        
        SyncManager.session.start { (error) in
            XCTAssert(error == nil)
            
            XCTAssert(downloadCount == 2)
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait {
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
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func uploadTwoFiles() -> (file1: ServerAPI.File, file2: ServerAPI.File, masterVersion:MasterVersionInt)? {
    
        let masterVersion = getMasterVersion()

        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString

        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file1) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        guard let (_, file2) = uploadFile(fileURL:fileURL, mimeType: "text/plain", fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        return (file1, file2, masterVersion)
    }
    
    func testStartWithTwoUploadedFilesOnServer() {
        guard let (file1, file2, masterVersion) = uploadTwoFiles() else {
            XCTFail()
            return
        }
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion)
    }
    
    // Simulation of master version change on server-- by changing it locally.
    func testWhereMasterVersionChangesMidwayThroughTwoDownloads() {
        var numberDownloads = 0
 
        guard let (file1, file2, masterVersion) = uploadTwoFiles() else {
            XCTFail()
            return
        }
        
        let singleFileDownload = {
            numberDownloads += 1
            if numberDownloads == 1 {
                CoreData.sessionNamed(Constants.coreDataName).performAndWait {
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
        
        downloadTwoFilesUsingStart(file1: file1, file2: file2, masterVersion: masterVersion, singleFileDownloaded: singleFileDownload)
    }
}
