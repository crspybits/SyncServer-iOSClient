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
    @discardableResult
    func sequentialUploadNextVersion(fileUUID:String, expectedVersion: FileVersionInt, fileURL:SMRelativeLocalURL? = nil) -> URL {
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
        
        return url
    }
    
    // 1a) upload the same file UUID several times, sequentially. i.e., do a sync after queuing it each time.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    func testSequentialVersionUploadWorks() {
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
    func testConcurrentVersionUploadWorks() {
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let urls = [url1, url2]
        let fileUUID = UUID().uuidString

        SyncServer.session.eventsDesired = [.syncDone]
        let syncDone = self.expectation(description: "test1")
        
        let numberSyncDoneExpected = 2
        var numberSyncDone = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                numberSyncDone += 1
                if numberSyncDone == numberSyncDoneExpected {
                    syncDone.fulfill()
                }
                
            default:
                XCTFail()
            }
        }
        
        let version:FileVersionInt = 1
        for index in 0...version {
            let attr = SyncAttributes(fileUUID: fileUUID, mimeType: "text/plain")
            let url = urls[Int(index)]
            
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            SyncServer.session.sync()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(expectedFiles: [
            (fileUUID: fileUUID, fileSize: nil),
        ])
        
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
            guard let dirEntry = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(dirEntry.fileVersion == version)
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, mimeType: nil, cloudFolderName: nil, deviceUUID: nil, appMetaData: nil, fileVersion: version)
        
        // Expecting last file contents uploaded.
        let url = urls[urls.count - 1]
        
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion)
    }
    
    // What happens if you queue the same time several times without calling sync? It gets replaced-- no version update. See docs for uploadImmutable.
    
    // Returns the fileUUID
    @discardableResult
    func uploadVersion(_ maxVersion:FileVersionInt) -> (fileUUID: String, URL) {
        let fileUUID = UUID().uuidString
        let url = sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 0)
        
        if maxVersion > 0 {
            for version in 1...maxVersion {
                sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: version)
            }
        }
        
        return (fileUUID, url)
    }
    
    /* 2) File download various file versions
        i.e., Use sync to upload different file versions, e.g., version 1 of file UUID X, version 3 of file UUID Y. Reset local meta data. Sync again. Should get those different file versions.
    */
    func testFileDownloadOfDifferentVersions() {
        let (fileUUID1, url1) = uploadVersion(1)
        let (fileUUID2, url2) = uploadVersion(3)
        
        let urls = [fileUUID1: url1,
            fileUUID2: url2]
        do {
            try SyncServer.session.reset()
        } catch (let error) {
            XCTFail("\(error)")
            return
        }
        
        let shouldSaveExp = self.expectation(description: "shouldSaveExp")

        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        shouldSaveDownload = { url, attr in
            downloadCount += 1
            guard let originalURL = urls[attr.fileUUID] else {
                XCTFail()
                return
            }
            
            XCTAssert(FilesMisc.compareFiles(file1: originalURL, file2: url as URL))
            
            XCTAssert(downloadCount <= 2)
            if downloadCount >= 2 {
                shouldSaveExp.fulfill()
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
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        // Make sure the files/versions are in our file index.
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            guard let file1 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID1),
            let file2 = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID2) else {
                XCTFail()
                return
            }

            XCTAssert(file1.fileVersion == 1)
            XCTAssert(file2.fileVersion == 3)
        }
    }
    
    // Upload delete some higher numbered file version-- will have to upload the same file several times first.
    func testUploadDeleteHigherNumberedFileVersionWorks() {
        let fileVersion:FileVersionInt = 3
        
        let (fileUUID, _) = uploadVersion(fileVersion)
        
        SyncServer.session.eventsDesired = [.syncDone, .uploadDeletionsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let uploadDeletion = self.expectation(description: "uploadDeletion")

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
            
            case .uploadDeletionsCompleted(let numberOfFiles):
                XCTAssert(numberOfFiles == 1)
                uploadDeletion.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: fileUUID)
        SyncServer.session.sync()

        waitForExpectations(timeout: 30.0, handler: nil)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            guard let file = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(file.deletedOnServer)
            XCTAssert(file.fileVersion == fileVersion)
        }
    }
    
    func testDownloadDeleteHigherNumberedFileVersion() {
        let fileVersion:FileVersionInt = 3
        let (fileUUID, _) = uploadVersion(fileVersion)
        
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }
        
        // Upload delete the file-- but don't use sync system so we don't record it in our local meta data.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)

        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        let done = self.expectation(description: "done")
        let deletionsExp = self.expectation(description: "deletions")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        shouldDoDeletions = { deletions in
            XCTAssert(deletions.count == 1)
            XCTAssert(deletions[0].fileUUID == fileUUID)
            deletionsExp.fulfill()
        }
        
        // Next, initiate the download using .sync()
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // MARK: Conflict resolution
    
    // Deletion conflict: a file is being download deleted, but there is a pending upload for the same file. A) Choose to accept the download deletion.
    func testDownloadDeletionConflict_AcceptDownloadDeletion() {
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        let (fileUUID, _) = uploadVersion(fileVersion)

        // 2) Upload delete the file, not using the sync system.
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // 3) Queue up a file upload of the same file.
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let downloadDeletionCallback = self.expectation(description: "downloadDeletion")
        
        // 4) Accept the download deletion.
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == "text/plain")
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            XCTAssert(uploadConflict.conflictType == .fileUpload)
            uploadConflict.resolutionCallback(.acceptDownloadDeletion)
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        shouldDoDeletions = { downloadDeletions in
            guard downloadDeletions.count == 1 else {
                XCTFail()
                return
            }
            
            let downloadDeletion = downloadDeletions[0]
            XCTAssert(downloadDeletion.fileUUID == fileUUID)
            downloadDeletionCallback.fulfill()
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: "text/plain")
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Deletion conflict: a file is being download deleted, but there is a pending upload for the same file. B) Choose to refuse the deletion-- do an upload undeletion.
    func testDownloadDeletionConflict_RefuseDownloadDeletion_KeepUpload() {
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        let (fileUUID, _) = uploadVersion(fileVersion)

        // 2) Upload delete the file, not using the sync system.
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // 3) Queue up a file upload of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let uploads = self.expectation(description: "uploads")
        
        // 4) Reject the download deletion- and keep the upload.
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == "text/plain")
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            XCTAssert(uploadConflict.conflictType == .fileUpload)
            uploadConflict.resolutionCallback(.rejectDownloadDeletion(.keepFileUpload))
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .fileUploadsCompleted(let numberUploads):
                XCTAssert(numberUploads == 1)
                uploads.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        shouldDoDeletions = { downloadDeletions in
            XCTFail()
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: "text/plain")
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testDownloadDeletionConflict_RefuseDownloadDeletion_RemoveUpload() {
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        let (fileUUID, _) = uploadVersion(fileVersion)

        // 2) Upload delete the file, not using the sync system.
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // 3) Queue up a file upload of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        
        // 4) Reject the download deletion- and keep the upload.
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == "text/plain")
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            XCTAssert(uploadConflict.conflictType == .fileUpload)
            uploadConflict.resolutionCallback(
                .rejectDownloadDeletion(.removeFileUpload))
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .fileUploadsCompleted:
                XCTFail()
                
            default:
                XCTFail()
            }
        }
        
        shouldDoDeletions = { downloadDeletions in
            XCTFail()
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, mimeType: "text/plain")
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Deletion conflicts need to test for the new middle case I've added: bothFileUploadAndDeletion

    // A file is being download deleted, and there is a pending upload deletion for the same file. This should *not* report a download deletion to the delegate callback-- the client already knows about the deletion.
    func testDownloadDeletionWithPendingUploadDeletion() {
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 0
        let (fileUUID, _) = uploadVersion(fileVersion)

        // 2) Upload delete the file, not using the sync system.
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        // 3) Queue up an upload deletion of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            XCTFail()
        }
        
        shouldDoDeletions = { deletions in
            XCTFail()
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .fileUploadsCompleted:
                XCTFail()
                
            default:
                XCTFail()
            }
        }
        
        shouldDoDeletions = { downloadDeletions in
            XCTFail()
        }
        
        try! SyncServer.session.delete(fileWithUUID: fileUUID)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        // Make sure the file is marked as deleted in our local file index.
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            guard let file = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }

            XCTAssert(file.deletedOnServer)
        }
    }
    
    /* Cases for file-download conflict:
        acceptFileDownload
        rejectFileDownload
            file uploads    upload deletion
            keep            keep
            keep            reject
            reject          keep
            reject          reject
     
        Test name coding:
     
        testFileDownloadConflict_[Accept|Reject]_[FU<N>_[Keep|Remove]_][UD<N>_[Keep|Remove]]
     
        FU= File Upload
        UD= Upload Deletion
        The <N> refers to the number of these pending.
    */
    func fileDownloadConflict(numberFileUploads: Int, uploadDeletion: Bool, resolution:FileDownloadResolution) {
    
        var numberSyncDoneExpected = numberFileUploads + (uploadDeletion ? 1 : 0)
        var actualNumberSyncDone = 0
        var numberUploadsExpected = numberFileUploads
        var actualNumberUploads = 0
        
        var conflictTypeExpected:
            SyncServerConflict<FileDownloadResolution>.ClientOperation
        if numberFileUploads > 0 && uploadDeletion {
            conflictTypeExpected = .bothFileUploadAndDeletion
        }
        else if numberFileUploads > 0 {
            conflictTypeExpected = .fileUpload
        }
        else {
            conflictTypeExpected = .uploadDeletion
        }
    
        let mimeType = "text/plain"
        let fileURL = SMRelativeLocalURL(withRelativePath: "UploadMe.txt", toBaseURLType: .mainBundle)!
        
        // 1) Upload a file, not using the sync system.
        let masterVersion = getMasterVersion()
        
        guard let (_, file) = uploadFile(fileURL:fileURL as URL, mimeType: mimeType, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)

        // 2) Setup our callbacks & expectations
        let done = self.expectation(description: "done")
        var fileUploadExp:XCTestExpectation?
        var uploadDeletionExp:XCTestExpectation?
        var saveDownloadsExp:XCTestExpectation?
        
        var uploadResolution:FileDownloadResolution.UploadResolution?

        switch resolution {
        case .acceptFileDownload:
            saveDownloadsExp = self.expectation(description: "saveDownloadsExp")
            
        case .rejectFileDownload(let upRes):
            uploadResolution = upRes
            
            if upRes.keepFileUploads {
                fileUploadExp = self.expectation(description: "fileUploadExp")
            }
            
            if upRes.keepUploadDeletions {
                uploadDeletionExp = self.expectation(description: "uploadDeletionExp")
            }
        }

        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted, .uploadDeletionsCompleted]
        SyncServer.session.delegate = self
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                actualNumberSyncDone += 1
                if actualNumberSyncDone == numberSyncDoneExpected {
                    done.fulfill()
                }
                
            case .fileUploadsCompleted(let num):
                Log.msg("uploadResolution: \(String(describing: uploadResolution))")
                XCTAssert(num == 1)
                
                actualNumberUploads += 1
                if actualNumberUploads < numberUploadsExpected {
                    break
                }
                
                if let uploadResolution = uploadResolution, uploadResolution.keepFileUploads {
                    guard let fileUploadExp = fileUploadExp else {
                        XCTFail()
                        return
                    }
                    fileUploadExp.fulfill()
                }
                else {
                    XCTFail()
                }
                
            case .uploadDeletionsCompleted(let numberDeletions):
                if let uploadResolution = uploadResolution, uploadResolution.keepUploadDeletions {
                    XCTAssert(uploadDeletion)
                    XCTAssert(numberDeletions == 1)
                    guard let uploadDeletionExp = uploadDeletionExp else {
                        XCTFail()
                        return
                    }
                    uploadDeletionExp.fulfill()
                }
                else {
                    XCTFail()
                }
                
            default:
                XCTFail()
            }
        }
        
        syncServerMustResolveFileDownloadConflict = { (downloadedFile: SMRelativeLocalURL, downloadedFileAttributes: SyncAttributes, uploadConflict: SyncServerConflict<FileDownloadResolution>) in
            XCTAssert(downloadedFileAttributes.fileUUID == file.fileUUID)
            XCTAssert(downloadedFileAttributes.mimeType == mimeType)
            
            XCTAssert(uploadConflict.conflictType == conflictTypeExpected)
            uploadConflict.resolutionCallback(resolution)
        }
        
        shouldSaveDownload = { (downloadedFile: NSURL,  downloadedFileAttributes: SyncAttributes) in
            if case .acceptFileDownload = resolution {
                XCTAssert(downloadedFileAttributes.fileUUID == file.fileUUID)
                XCTAssert(downloadedFileAttributes.mimeType == mimeType)
                guard let saveDownloadsExp = saveDownloadsExp else {
                    XCTFail()
                    return
                }
                saveDownloadsExp.fulfill()
            }
            else {
                XCTFail()
            }
        }

        // 3) Queue up uploads and/or upload deletions. Note that these will kick off immediately, but will cause a file index request which shouldn't finish before all of these are queued up. In theory a race condition, but not in practice.
        
        if numberFileUploads > 0 {
            for _ in 1...numberFileUploads {
                let attr = SyncAttributes(fileUUID: file.fileUUID, mimeType: mimeType)
                try! SyncServer.session.uploadImmutable(localFile: fileURL, withAttributes: attr)
                SyncServer.session.sync()
            }
        }
        
        if uploadDeletion {
            try! SyncServer.session.delete(fileWithUUID: file.fileUUID)
            SyncServer.session.sync()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    func testFileDownloadConflict_Accept_FU1_UD0() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .acceptFileDownload)
    }
    
    func testFileDownloadConflict_Accept_FU2_UD0() {
        fileDownloadConflict(numberFileUploads: 2, uploadDeletion: false, resolution: .acceptFileDownload)
    }
    
    func testFileDownloadConflict_Accept_FU1_UD1() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .acceptFileDownload)
    }
    
    func testFileDownloadConflict_Reject_FU1_Remove_UD0() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .rejectFileDownload(.removeAll))
    }

   func testFileDownloadConflict_Reject_FU1_Keep_UD0() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .rejectFileDownload(.keepFileUploads))
    }

    func testFileDownloadConflict_Reject_FU2_Keep_UD0() {
        fileDownloadConflict(numberFileUploads: 2, uploadDeletion: false, resolution: .rejectFileDownload(.keepFileUploads))
    }
    
    func testFileDownloadConflict_Reject_FU1_Keep_UD1() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectFileDownload(.keepFileUploads))
    }
    
    func testFileDownloadConflict_Reject_FU1_Remove_UD1_Keep() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectFileDownload(.keepUploadDeletions))
    }
    
    func testFileDownloadConflict_Reject_FU1_Keep_UD1_Keep() {
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectFileDownload(.keepAll))
    }
    
/*
1) What happens if you empty a queue in the upload queues by removing pending deletions?
    To test this, queue an upload deletion. Then, receive a download deletion (someone else deleted the file first).
It would also be good to (a) queue an independent upload and call sync, then (b) queue an upload deletion and call sync. Then, receive a download deletion (someone else deleted the file first).

2) Queue upload deletion, sync, queue upload deletion, sync. Then get a download deletion. (Is this double upload deletion/sync of the same UUID allowed? I think we should *not* allow this-- CHECK!).

3) What happens if you queue a file, sync, queue the same file, sync, then receive a download deletion for that file?
    Try this with (a) keeping client operations and (b) deleting client operations;
 
4) Queue upload deletion, sync, queue upload deletion, sync. Then get a file download for the same file. (Is this double upload deletion/sync of the same UUID allowed?).
*/
    
    // What happens when a file locally marked as deleted gets downloaded again, because someone else did an upload undeletion? Have we covered that case? We ought to get a `syncServerSingleFileDownloadComplete` delegate callback. Need to make sure of that.
}
