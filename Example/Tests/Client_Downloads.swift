//
//  Client_Downloads.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class Client_Downloads: TestCase {
    
    override func setUp() {
        super.setUp()
        
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func checkForDownloads(expectedMasterVersion:MasterVersionInt, expectedFiles:[ServerAPI.File]) {
        
        let expectation = self.expectation(description: "check")

        Download.session.check() { checkCompletion in
            switch checkCompletion {
            case .noDownloadsOrDeletionsAvailable:
                XCTAssert(expectedFiles.count == 0)
            
            case .downloadsAvailable(numberOfContentDownloads: let numberOfContentDownloads, numberOfDownloadDeletions: let numDeletions):
                let total = numberOfContentDownloads + numDeletions
                XCTAssert(Int32(expectedFiles.count) == total, "numDownloads: \(total); expectedFiles.count: \(expectedFiles.count)")
                
            case .error(_):
                XCTFail()
            }
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait {
                XCTAssert(Singleton.get().masterVersion == expectedMasterVersion)

                let dfts = DownloadFileTracker.fetchAll()
                XCTAssert(dfts.count == expectedFiles.count, "dfts.count: \(dfts.count); expectedFiles.count: \(expectedFiles.count)")

                for file in expectedFiles {
                    let dftsResult = dfts.filter { $0.fileUUID == file.fileUUID &&
                        $0.fileVersion == file.fileVersion
                    }
                    XCTAssert(dftsResult.count == 1)
                }
                
                let entries = DirectoryEntry.fetchAll()
                XCTAssert(entries.count == 0)
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testCheckForDownloadOfZeroFilesWorks() {
        let masterVersion = getMasterVersion()
        checkForDownloads(expectedMasterVersion: masterVersion, expectedFiles: [])
    }
    
    func testCheckForDownloadOfSingleFileWorks() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])
    }
    
    func testCheckForDownloadOfTwoFilesWorks() {
        let masterVersion = getMasterVersion()
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file1) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let (_, file2) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 2)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file1, file2])
    }
    
    func testDownloadNextWithNoFilesOnServer() {
        let masterVersion = getMasterVersion()
        checkForDownloads(expectedMasterVersion: masterVersion, expectedFiles: [])
    
        let result = Download.session.next() { completionResult in
            XCTFail()
        }
        
        guard case .noDownloadsOrDeletions = result else {
            XCTFail()
            return
        }
    }
    
    func testDownloadNextWithOneFileNotDownloadedOnServer() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])

        let expectation = self.expectation(description: "next")

        let result = Download.session.next() { completionResult in
            guard case .fileDownloaded(let url, _, _) = completionResult else {
                XCTFail()
                return
            }
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait {
                let dfts = DownloadFileTracker.fetchAll()
                XCTAssert(dfts[0].fileVersion == file.fileVersion)
                XCTAssert(dfts[0].status == .downloaded)

                XCTAssert(self.filesHaveSameContents(url1: file.localURL, url2: url as URL))
            }
            
            expectation.fulfill()
        }
        
        guard case .started = result else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts[0].status == .downloading)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadNextWithMasterVersionUpdate() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            // Fake an incorrect master version.
            Singleton.get().masterVersion = masterVersion
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
        }
        
        let expectation = self.expectation(description: "next")

        let result = Download.session.next() { completionResult in
            guard case .masterVersionUpdate = completionResult else {
                XCTFail()
                return
            }
            
            expectation.fulfill()
        }
        
        guard case .started = result else {
            XCTFail()
            return
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts[0].status == .downloading)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testThatTwoNextsWithOneFileGivesAllDownloadsCompleted() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])

        // First next should work as usual
        let expectation1 = self.expectation(description: "next1")
        let _ = Download.session.next() { completionResult in
            guard case .fileDownloaded = completionResult else {
                XCTFail()
                return
            }
            
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        
        // Second next should indicate `allDownloadsCompleted`
        let result = Download.session.next() { completionResult in
            XCTFail()
        }
        
        guard case .allDownloadsCompleted = result else {
            XCTFail()
            return
        }
    }
    
    func testNextImmediatelyFollowedByNextIndicatesDownloadAlreadyOccurring() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, expectedFiles: [file])

        let expectation = self.expectation(description: "next")

        let _ = Download.session.next() { completionResult in
            guard case .fileDownloaded = completionResult else {
                XCTFail()
                return
            }
            
            expectation.fulfill()
        }
        
        // This second `next` should fail: We already have a download occurring.
        let result = Download.session.next() { completionResult in
            XCTFail()
        }
        guard case .error(_) = result else {
            XCTFail()
            return
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func onlyCheck(expectedDownloads:Int=0, expectedDownloadDeletions:Int=0) {
        let masterVersionFirst = getMasterVersion()
        let expectation1 = self.expectation(description: "onlyCheck")

        Download.session.onlyCheck { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                XCTFail("Failed: \(error)")
            
            case .checkResult(downloadSet: let downloadSet, let masterVersion):
                XCTAssert(downloadSet.downloadFiles.count == expectedDownloads, "count: \(downloadSet.downloadFiles.count)")
                XCTAssert(downloadSet.downloadDeletions.count == expectedDownloadDeletions, "\(downloadSet.downloadDeletions.count)")
                XCTAssert(downloadSet.downloadAppMetaData.count == 0)
                XCTAssert(masterVersion == masterVersionFirst)
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testOnlyCheckWhenNoFiles() {
        onlyCheck()
    }
    
    func testOnlyCheckWhenOneFileForDownload() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        onlyCheck(expectedDownloads:1)
    }
    
    func testOnlyCheckWhenOneFileForDownloadDeletion() {
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart() else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        onlyCheck(expectedDownloadDeletions:1)
    }
}
