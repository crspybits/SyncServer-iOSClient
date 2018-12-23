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
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func checkForDownloads(expectedMasterVersion:MasterVersionInt, sharingGroupUUID: String, expectedFiles:[ServerAPI.File]) {
        
        let expectation = self.expectation(description: "check")

        Download.session.check(sharingGroupUUID: sharingGroupUUID) { checkCompletion in
            switch checkCompletion {
            case .noDownloadsOrDeletionsAvailable:
                XCTAssert(expectedFiles.count == 0)
            
            case .downloadsAvailable(numberOfContentDownloads: let numberOfContentDownloads, numberOfDownloadDeletions: let numDeletions):
                let total = numberOfContentDownloads + numDeletions
                XCTAssert(Int32(expectedFiles.count) == total, "numDownloads: \(total); expectedFiles.count: \(expectedFiles.count)")
                
            case .error(_):
                XCTFail()
            }
            
            guard let masterVersion = self.getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
                XCTFail()
                return
            }
        
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                XCTAssert(masterVersion == expectedMasterVersion)

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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        checkForDownloads(expectedMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedFiles: [])
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testCheckForDownloadOfSingleFileWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file])
        
        // There *will* be download trackers in normal operation at the end of this test. Don't do this assertion.
        // assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testCheckForDownloadOfTwoFilesWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file1 = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion) else {
            return
        }
        
        guard let file2 = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file1, file2])
    }
    
    func testDownloadNextWithNoFilesOnServer() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        checkForDownloads(expectedMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedFiles: [])
    
        let result = Download.session.next() { completionResult in
            XCTFail()
        }
        
        guard case .noDownloadsOrDeletions = result else {
            XCTFail("\(result)")
            return
        }
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testDownloadNextWithOneFileNotDownloadedOnServer() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file])

        let expectation = self.expectation(description: "next")

        let result = Download.session.next() { completionResult in
            guard case .fileDownloaded(let dft) = completionResult else {
                XCTFail()
                return
            }
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                let dfts = DownloadFileTracker.fetchAll()
                XCTAssert(dfts[0].fileVersion == file.fileVersion)
                XCTAssert(dfts[0].status == .downloaded)

                XCTAssert(self.filesHaveSameContents(url1: file.localURL, url2: dft.localURL! as URL))
            }
            
            expectation.fulfill()
        }
        
        guard case .started = result else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts[0].status == .downloading)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadNextWithMasterVersionUpdate() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file])
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // Fake an incorrect master version.
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
            
            sharingEntry.masterVersion = masterVersion

            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
        }
        
        let expectation = self.expectation(description: "next")

        let result = Download.session.next() { completionResult in
            guard case .masterVersionUpdate = completionResult else {
                XCTFail("\(completionResult)")
                return
            }
            
            expectation.fulfill()
        }
        
        guard case .started = result else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts[0].status == .downloading)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testThatNextWithOneFileMarksGroupAsCompleted() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file])

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
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dcgs = DownloadContentGroup.fetchAll()
            guard dcgs.count == 1 else {
                XCTFail()
                return
            }
            XCTAssert(dcgs[0].allDftsCompleted())
        }
    }
    
    func testNextImmediatelyFollowedByNextIndicatesDownloadAlreadyOccurring() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        checkForDownloads(expectedMasterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, expectedFiles: [file])

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
    
    func onlyCheck(sharingGroupUUID: String, expectedDownloads:Int=0, expectedDownloadDeletions:Int=0) {        
        let expectation1 = self.expectation(description: "onlyCheck")

        Download.session.onlyCheck(sharingGroupUUID: sharingGroupUUID) { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                XCTFail("Failed: \(error)")
            
            case .checkResult(downloadSet: let downloadSet):
                XCTAssert(downloadSet.downloadFiles.count == expectedDownloads, "count: \(downloadSet.downloadFiles.count)")
                XCTAssert(downloadSet.downloadDeletions.count == expectedDownloadDeletions, "\(downloadSet.downloadDeletions.count)")
                XCTAssert(downloadSet.downloadAppMetaData.count == 0)
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testOnlyCheckWhenNoFiles() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        onlyCheck(sharingGroupUUID: sharingGroupUUID)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [sharingGroupUUID])
    }
    
    func testOnlyCheckWhenOneFileForDownload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        onlyCheck(sharingGroupUUID: sharingGroupUUID, expectedDownloads:1)
    }
    
    func testOnlyCheckWhenOneFileForDownloadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Uses SyncManager.session.start so we have the file in our local Directory after download.
        guard let (file, masterVersion) = uploadAndDownloadOneFileUsingStart(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        // Simulate another device deleting the file.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        
        self.doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        onlyCheck(sharingGroupUUID: sharingGroupUUID, expectedDownloadDeletions:1)
    }
}
