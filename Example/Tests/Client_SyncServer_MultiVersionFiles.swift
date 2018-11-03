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
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Multi-version files
    
    // uploads text files.
    @discardableResult
    func sequentialUploadNextVersion(fileUUID:String, expectedVersion: FileVersionInt, sharingGroupUUID: String, fileURL:SMRelativeLocalURL? = nil) -> SMRelativeLocalURL? {
        
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, fileURL:fileURL) else {
            XCTFail()
            return nil
        }
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [attr.fileUUID])
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let dirEntry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(dirEntry.fileVersion == expectedVersion)
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: attr.fileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: expectedVersion, checkSum: "")
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
        
        return url
    }
    
    // 1a) upload the same file UUID several times, sequentially. i.e., do a sync after queuing it each time.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    func testSequentialVersionUploadWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileUUID = UUID().uuidString
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 0, sharingGroupUUID: sharingGroupUUID)
        
        let url2 = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 1, sharingGroupUUID: sharingGroupUUID, fileURL: url2)
        
        let url3 = SMRelativeLocalURL(withRelativePath: "UploadMe4.txt", toBaseURLType: .mainBundle)!
        sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 2, sharingGroupUUID: sharingGroupUUID, fileURL: url3)
    }
    
    // 1b) queue for upload the same file several times, concurrently. Don't do a sync until queuing each one.
    // Make sure that different versions get uploaded each time.
    // And that the directory entry has the right version after the last upload.
    func testConcurrentVersionUploadWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
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
            let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
            let url = urls[Int(index)]
            
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID,
        ])
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let dirEntry = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(dirEntry.fileVersion == version)
        }
        
        let file = ServerAPI.File(localURL: nil, fileUUID: fileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: nil, deviceUUID: nil, appMetaData: nil, fileVersion: version, checkSum: "")
        
        // Expecting last file contents uploaded.
        let url = urls[urls.count - 1]
        
        onlyDownloadFile(comparisonFileURL: url as URL, file: file, masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID)
    }
    
    // What happens if you queue the same time several times without calling sync? It gets replaced-- no version update. See docs for uploadImmutable.
    
    // Returns the fileUUID
    @discardableResult
    func uploadVersion(_ maxVersion:FileVersionInt, sharingGroupUUID: String) -> (fileUUID: String, SMRelativeLocalURL)? {
        let fileUUID = UUID().uuidString
        guard let url = sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: 0, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        if maxVersion > 0 {
            for version in 1...maxVersion {
                sequentialUploadNextVersion(fileUUID:fileUUID, expectedVersion: version, sharingGroupUUID: sharingGroupUUID)
            }
        }
        
        return (fileUUID, url)
    }
    
    /* 2) File download various file versions
        i.e., Use sync to upload different file versions, e.g., version 1 of file UUID X, version 3 of file UUID Y. Reset local meta data. Sync again. Should get those different file versions.
    */
    func testFileDownloadOfDifferentVersions() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let (fileUUID1, url1) = uploadVersion(1, sharingGroupUUID: sharingGroupUUID),
            let (fileUUID2, url2) = uploadVersion(3, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let urls = [fileUUID1: url1,
            fileUUID2: url2]
        do {
            try SyncServer.session.reset(type: .all)
        } catch (let error) {
            XCTFail("\(error)")
            return
        }
        
        // Need to re-initialize our local info about sharing groups. We've lost that.
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        let shouldSaveExp = self.expectation(description: "shouldSaveExp")

        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url, let contentsChanged) = group[0].type {
                XCTAssert(!contentsChanged)
                let attr = group[0].attr
                downloadCount += 1
                guard let originalURL = urls[attr.fileUUID] else {
                    XCTFail()
                    return
                }
                
                XCTAssert(FilesMisc.compareFiles(file1: originalURL as URL, file2: url as URL))
                
                XCTAssert(downloadCount <= 2)
                if downloadCount >= 2 {
                    shouldSaveExp.fulfill()
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
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        // Make sure the files/versions are in our file index.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileVersion:FileVersionInt = 3
        
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
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
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)

        waitForExpectations(timeout: 30.0, handler: nil)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let file = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(file.deletedLocally)
            XCTAssert(file.fileVersion == fileVersion)
        }
    }
    
    func testDownloadDeleteHigherNumberedFileVersion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileVersion:FileVersionInt = 3
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        // Upload delete the file-- but don't use sync system so we don't record it in our local meta data.
        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

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
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            XCTAssert(group[0].attr.fileUUID == fileUUID)
            deletionsExp.fulfill()
        }
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // MARK: Conflict resolution
    
    func downloadDeletionConflict_AcceptDownloadDeletion(numberUploads:Int) {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Queue up file upload(s) of the same file.
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
            XCTAssert(deletion.mimeType == MimeType.text)
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            
            XCTAssert(uploadConflict.conflictType == .contentUpload(.file))

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
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1, case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            XCTAssert(group[0].attr.fileUUID == fileUUID)
            downloadDeletionCallback.fulfill()
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        for _ in 1...numberUploads {
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Deletion conflict: a file is being download deleted, but there are pending upload(s) for the same file. A) Choose to accept the download deletion.
    func testDownloadDeletionConflict_AcceptDownloadDeletion_1() {
        downloadDeletionConflict_AcceptDownloadDeletion(numberUploads: 1)
    }
    
    func testDownloadDeletionConflict_AcceptDownloadDeletion_2() {
        downloadDeletionConflict_AcceptDownloadDeletion(numberUploads: 2)
    }
    
    func downloadDeletionConflict_RefuseDownloadDeletion_KeepUpload(numberUploadsToDo:Int, sharingGroupUUID: String) {
        var actualNumberUploads = 0
        
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Queue up file upload(s) of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let uploads = self.expectation(description: "uploads")
        
        // 4) Reject the download deletion- and keep the upload(s).
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == .text)
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            
            XCTAssert(uploadConflict.conflictType == .contentUpload(.file))
            
            uploadConflict.resolutionCallback(
                .rejectDownloadDeletion(.keepContentUpload))
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                if actualNumberUploads == numberUploadsToDo {
                    done.fulfill()
                }
                
            case .contentUploadsCompleted(let numberUploads):
                XCTAssert(numberUploads == 1)
                actualNumberUploads += 1
                if actualNumberUploads == numberUploadsToDo {
                    uploads.fulfill()
                }
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTFail()
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        for _ in 1...numberUploadsToDo {
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Deletion conflict: a file is being download deleted, but there is a pending upload for the same file. B) Choose to refuse the deletion-- do an upload undeletion.
    func testDownloadDeletionConflict_RefuseDownloadDeletion_KeepUpload_1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadDeletionConflict_RefuseDownloadDeletion_KeepUpload(numberUploadsToDo:1, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testDownloadDeletionConflict_RefuseDownloadDeletion_KeepUpload_2() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        downloadDeletionConflict_RefuseDownloadDeletion_KeepUpload(numberUploadsToDo:2, sharingGroupUUID: sharingGroupUUID)
    }
    
    // This is an error because a purely appMetaData upload cannot undelete a file-- because it can't replace the previously deleted file content.
    func testDownloadDeletionConflict_RefuseDownloadDeletion_KeepAppMetaDataUpload_Fails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload a file-- uses sync system.
        let fileVersion:FileVersionInt = 3
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file, not using the sync system. This will cause the download deletion we're looking for.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Queue up an appMetaData upload of the same file.
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let conflictExp = self.expectation(description: "conflict")
        let errorExp = self.expectation(description: "error")
        let deletion = self.expectation(description: "deletion")
        
        // 4) Reject the download deletion- and keep the appMetaData upload(s).
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == .text)
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            
            XCTAssert(uploadConflict.conflictType == .contentUpload(.appMetaData))
            
            // This is the error-- can't `.keepContentUpload` for a purely appMetaData upload.
            uploadConflict.resolutionCallback(
                .rejectDownloadDeletion(.keepContentUpload))
            
            conflictExp.fulfill()
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            guard case .deletion = group[0].type else {
                XCTFail()
                return
            }
            
            deletion.fulfill()
        }
        
        syncServerErrorOccurred = { error in
            errorExp.fulfill()
        }
        
        var attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        attr.appMetaData = "Some app meta data"
        
        try! SyncServer.session.uploadAppMetaData(attr: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Since we're refusing the download deletion and removing the upload, we will get a following download-- to delete the file.
    func testDownloadDeletionConflict_RefuseDownloadDeletion_RemoveUpload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 3
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Queue up a file upload of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        
        var expectSyncServerFileGroupDownloadComplete = false
        
        // 4) Reject the download deletion- and remove the upload.
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            let deletion = conflict.downloadDeletion
            XCTAssert(deletion.mimeType == .text)
            XCTAssert(deletion.fileUUID == fileUUID)
            
            let uploadConflict = conflict.uploadConflict
            
            XCTAssert(uploadConflict.conflictType == .contentUpload(.file))
            
            uploadConflict.resolutionCallback(
                .rejectDownloadDeletion(.removeContentUpload))
                
            XCTAssert(!expectSyncServerFileGroupDownloadComplete)
            expectSyncServerFileGroupDownloadComplete = true
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .contentUploadsCompleted:
                XCTFail()
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTAssert(expectSyncServerFileGroupDownloadComplete)
            
            guard group.count == 1 else {
                XCTFail()
                return
            }
            
            let content = group[0]
            guard case .deletion = content.type else {
                XCTFail()
                return
            }
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe3.txt", toBaseURLType: .mainBundle)!
        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    // Deletion conflicts need to test for the new middle case I've added: bothFileUploadAndDeletion

    // A file is being download deleted, and there is a pending upload deletion for the same file. This should *not* report a download deletion to the delegate callback-- the client already knows about the deletion.
    func testDownloadDeletionWithPendingUploadDeletion() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload a file.
        let fileVersion:FileVersionInt = 0
        guard let (fileUUID, _) = uploadVersion(fileVersion, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: fileUUID, fileVersion: fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Queue up an upload deletion of the same file.
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            XCTFail()
        }
        
        syncServerFileGroupDownloadComplete = { group in
            XCTFail()
        }
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .contentUploadsCompleted:
                XCTFail()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: fileUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        // Make sure the file is marked as deleted in our local file index.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let file = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID) else {
                XCTFail()
                return
            }

            XCTAssert(file.deletedLocally)
        }
    }
    
    func fileDownloadConflict(numberFileUploads: Int, uploadDeletion: Bool, resolution:ContentDownloadResolution, sharingGroupUUID: String) {
    
        let numberSyncDoneExpected = numberFileUploads + (uploadDeletion ? 1 : 0)
        var actualNumberSyncDone = 0
        let numberUploadsExpected = numberFileUploads
        var actualNumberUploads = 0
        
        var conflictTypeExpected:ConflictingClientOperation
        if numberFileUploads > 0 && uploadDeletion {
            conflictTypeExpected = .both
        }
        else if numberFileUploads > 0 {
            conflictTypeExpected = .contentUpload(.file)
        }
        else {
            conflictTypeExpected = .uploadDeletion
        }
    
        let mimeType:MimeType = .text
        let fileURL = SMRelativeLocalURL(withRelativePath: "UploadMe.txt", toBaseURLType: .mainBundle)!
        
        // 1) Upload a file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let file = uploadFile(fileURL:fileURL as URL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        // 2) Setup our callbacks & expectations
        let done = self.expectation(description: "done")
        var fileUploadExp:XCTestExpectation?
        var uploadDeletionExp:XCTestExpectation?
        var saveDownloadsExp:XCTestExpectation?
        
        var uploadResolution:ContentDownloadResolution.UploadResolution?

        switch resolution {
        case .acceptContentDownload:
            saveDownloadsExp = self.expectation(description: "saveDownloadsExp")
            
        case .rejectContentDownload(let upRes):
            uploadResolution = upRes
            
            if upRes.keepContentUploads {
                fileUploadExp = self.expectation(description: "fileUploadExp")
            }
            
            if upRes.keepUploadDeletions {
                uploadDeletionExp = self.expectation(description: "uploadDeletionExp")
            }
        }

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .uploadDeletionsCompleted]
        SyncServer.session.delegate = self
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                actualNumberSyncDone += 1
                if actualNumberSyncDone == numberSyncDoneExpected {
                    done.fulfill()
                }
                
            case .contentUploadsCompleted(let num):
                Log.msg("uploadResolution: \(String(describing: uploadResolution))")
                XCTAssert(num == 1)
                
                actualNumberUploads += 1
                if actualNumberUploads < numberUploadsExpected {
                    break
                }
                
                if let uploadResolution = uploadResolution, uploadResolution.keepContentUploads {
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
        
        syncServerMustResolveContentDownloadConflict = { (content: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) in
            guard case .file = content else {
                XCTFail()
                return
            }
            XCTAssert(downloadedContentAttributes.fileUUID == file.fileUUID)
            XCTAssert(downloadedContentAttributes.mimeType == mimeType)
            
            XCTAssert(uploadConflict.conflictType == conflictTypeExpected)
            
            uploadConflict.resolutionCallback(resolution)
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                if case .acceptContentDownload = resolution {
                    let downloadedFileAttributes = group[0].attr
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
            else {
                XCTFail()
            }
        }

        // 3) Queue up uploads and/or upload deletions. Note that these will kick off immediately, but will cause a file index request which shouldn't finish before all of these are queued up. In theory a race condition, but not in practice.
        
        if numberFileUploads > 0 {
            for _ in 1...numberFileUploads {
                let attr = SyncAttributes(fileUUID: file.fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType)
                try! SyncServer.session.uploadImmutable(localFile: fileURL, withAttributes: attr)
                try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            }
        }
        
        if uploadDeletion {
            try! SyncServer.session.delete(fileWithUUID: file.fileUUID)
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
    enum DownloadType {
        case file
        case appMetaData
    }
    
    func appMetaDataConflict(downloadType: DownloadType = .file, sharingGroupUUID: String, numberAppMetaDataUploads: Int, numberFileUploads: Int = 0, uploadDeletion: Bool, resolution:ContentDownloadResolution) {
    
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        let fileUUID = attr.fileUUID!

        let numberSyncDoneExpected = numberFileUploads + numberAppMetaDataUploads + (uploadDeletion ? 1 : 0)
        var actualNumberSyncDone = 0
        let numberAppMetaDataUploadsExpected = numberAppMetaDataUploads
        var actualNumberUploads = 0
        
        var conflictTypeExpected:ConflictingClientOperation
        if (numberAppMetaDataUploads > 0 || numberFileUploads > 0) && uploadDeletion {
            conflictTypeExpected = .both
        }
        else if numberAppMetaDataUploads > 0 || numberFileUploads > 0 {
            if numberAppMetaDataUploads > 0 && numberFileUploads > 0 {
                conflictTypeExpected = .contentUpload(.both)
            }
            else if numberAppMetaDataUploads > 0 {
                conflictTypeExpected = .contentUpload(.appMetaData)
            }
            else {
                conflictTypeExpected = .contentUpload(.file)
            }
        }
        else {
            conflictTypeExpected = .uploadDeletion
        }
    
        let mimeType:MimeType = .text
        let fileURL = SMRelativeLocalURL(withRelativePath: "UploadMe.txt", toBaseURLType: .mainBundle)!
        
        // 1) Upload a file OR appMetaData, not using the sync system-- this is the download that will conflict with the following upload.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")

        switch downloadType {
        case .file:
            guard let _ = uploadFile(fileURL:fileURL as URL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: 1) else {
                XCTFail()
                return
            }
            
        case .appMetaData:
            guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
                XCTFail()
                return
            }
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        // 2) Setup our callbacks & expectations
        let done = self.expectation(description: "done")
        var fileUploadExp:XCTestExpectation?
        var uploadDeletionExp:XCTestExpectation?
        var saveDownloadsExp:XCTestExpectation?
        var saveDownloadAppMetaDataExp:XCTestExpectation?
        
        var uploadResolution:ContentDownloadResolution.UploadResolution?

        switch resolution {
        case .acceptContentDownload:
            switch downloadType {
            case .file:
                saveDownloadsExp = self.expectation(description: "saveDownloadsExp")

            case .appMetaData:
                saveDownloadAppMetaDataExp = self.expectation(description: "saveDownloadAppMetaDataExp")
            }

        case .rejectContentDownload(let upRes):
            uploadResolution = upRes
            
            if upRes.keepContentUploads {
                fileUploadExp = self.expectation(description: "fileUploadExp")
            }
            
            if upRes.keepUploadDeletions {
                uploadDeletionExp = self.expectation(description: "uploadDeletionExp")
            }
        }
        
        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .uploadDeletionsCompleted]
        SyncServer.session.delegate = self
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                actualNumberSyncDone += 1
                if actualNumberSyncDone == numberSyncDoneExpected {
                    done.fulfill()
                }
                
            case .contentUploadsCompleted(let num):
                Log.msg("uploadResolution: \(String(describing: uploadResolution))")
                XCTAssert(num == 1)
                
                actualNumberUploads += 1
                if actualNumberUploads < numberAppMetaDataUploadsExpected {
                    break
                }
                
                if let uploadResolution = uploadResolution, uploadResolution.keepContentUploads {
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
        
        syncServerMustResolveContentDownloadConflict = { (content: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) in
        
            switch downloadType {
            case .file:
                guard case .file = content else {
                    XCTFail()
                    return
                }
                
            case .appMetaData:
                guard case .appMetaData = content else {
                    XCTFail()
                    return
                }
            }
            
            XCTAssert(downloadedContentAttributes.fileUUID == fileUUID)
            XCTAssert(downloadedContentAttributes.mimeType == mimeType)
            
            XCTAssert(uploadConflict.conflictType == conflictTypeExpected, "conflictTypeExpected: \(conflictTypeExpected); uploadConflict.conflictType: \(uploadConflict.conflictType)")
            uploadConflict.resolutionCallback(resolution)
        }

        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1 {
                let attr = group[0].attr
                switch group[0].type {
                case .deletion:
                    XCTFail()
                case .appMetaData:
                    XCTAssert(attr.fileUUID == fileUUID)
                    XCTAssert(attr.appMetaData == appMetaData.contents)
                    saveDownloadAppMetaDataExp!.fulfill()
                case .file:
                    switch resolution {
                    case .acceptContentDownload:
                        XCTAssert(attr.fileUUID == fileUUID)
                        XCTAssert(attr.mimeType == mimeType)
                        
                        guard let saveDownloadsExp = saveDownloadsExp else {
                            XCTFail()
                            return
                        }
                        saveDownloadsExp.fulfill()
                    case .rejectContentDownload:
                        // Shouldn't be trying to save downloads if we're rejecting content downloads.
                        XCTFail()
                    }
                }
            }
            else {
                XCTFail()
            }
        }

        // 3) Queue up uploads and/or upload deletions. Note that these will kick off immediately, but will cause a file index request which shouldn't finish before all of these are queued up. In theory a race condition, but not in practice.
        
        if numberAppMetaDataUploads > 0 {
            for index in 1...numberAppMetaDataUploads {
                var attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType)
                attr.appMetaData = "foobar\(index)"
                try! SyncServer.session.uploadAppMetaData(attr: attr)
                try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            }
        }
        
        if numberFileUploads > 0 {
            for _ in 1...numberFileUploads {
                let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType)
                try! SyncServer.session.uploadImmutable(localFile: fileURL, withAttributes: attr)
                try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            }
        }
        
        if uploadDeletion {
            try! SyncServer.session.delete(fileWithUUID: fileUUID)
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        
        waitForExpectations(timeout: 60.0, handler: nil)
    }
    
    func testFileDownloadConflict_Accept_FU1_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .acceptContentDownload, sharingGroupUUID: sharingGroupUUID)
    }

    func testFileDownloadConflict_Accept_FU2_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 2, uploadDeletion: false, resolution: .acceptContentDownload, sharingGroupUUID: sharingGroupUUID)
    }

    func testFileDownloadConflict_Accept_FU1_UD1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .acceptContentDownload, sharingGroupUUID: sharingGroupUUID)
    }

    func testFileDownloadConflict_Reject_FU1_Remove_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .rejectContentDownload(.removeAll), sharingGroupUUID: sharingGroupUUID)
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

    func testFileDownloadConflict_Reject_FU1_Keep_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: false, resolution: .rejectContentDownload(.keepContentUploads), sharingGroupUUID: sharingGroupUUID)
    }

    func testFileDownloadConflict_Reject_FU2_Keep_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 2, uploadDeletion: false, resolution: .rejectContentDownload(.keepContentUploads), sharingGroupUUID: sharingGroupUUID)
    }
    
    func testFileDownloadConflict_Reject_FU1_Keep_UD1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepContentUploads), sharingGroupUUID: sharingGroupUUID)
    }
    
    func testFileDownloadConflict_Reject_FU1_Remove_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepUploadDeletions), sharingGroupUUID: sharingGroupUUID)
    }
    
    func testFileDownloadConflict_Reject_FU1_Keep_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        fileDownloadConflict(numberFileUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepAll), sharingGroupUUID: sharingGroupUUID)
    }
    
    func testAppMetaDataDownloadConflict_Accept_FU1_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: false, resolution: .acceptContentDownload)
    }

    func testAppMetaDataDownloadConflict_Accept_FU2_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 2, uploadDeletion: false, resolution: .acceptContentDownload)
    }

    func testAppMetaDataDownloadConflict_Accept_FU1_UD1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: true, resolution: .acceptContentDownload)
    }

    func testAppMetaDataDownloadConflict_Reject_FU1_Remove_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: false, resolution: .rejectContentDownload(.removeAll))
    }
    
    func testAppMetaDataDownloadConflict_Reject_FU1_Keep_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: false, resolution: .rejectContentDownload(.keepContentUploads))
    }
    
    func testAppMetaDataDownloadConflict_Reject_FU2_Keep_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 2, uploadDeletion: false, resolution: .rejectContentDownload(.keepContentUploads))
    }

    func testAppMetaDataDownloadConflict_Reject_FU1_Keep_UD1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepContentUploads))
    }

    func testAppMetaDataDownloadConflict_Reject_FU1_Remove_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepUploadDeletions))
    }
    
    func testAppMetaDataDownloadConflict_Reject_FU1_Keep_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepAll))
    }
    
    func testAppMetaData_Upload_DownloadConflict_Accept_FU1_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(downloadType: .appMetaData, sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: false, resolution: .acceptContentDownload)
    }
    
    func testAppMetaData_Upload_DownloadConflict_Reject_FU1_Keep_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(downloadType: .appMetaData, sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepAll))
    }
    
    // What happens now if you upload contents for a file, but have an app meta data download occur? i.e., in terms of conflicts?
    func testAppMetaData_FileUpload_DownloadConflict_Accept_FU1_UD0() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(downloadType: .appMetaData, sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 0, numberFileUploads: 1, uploadDeletion: false, resolution: .acceptContentDownload)
    }
    
    func testAppMetaData_FileUpload_DownloadConflict_Reject_FU1_Keep_UD1_Keep() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        appMetaDataConflict(downloadType: .appMetaData, sharingGroupUUID: sharingGroupUUID, numberAppMetaDataUploads: 0, numberFileUploads: 1, uploadDeletion: true, resolution: .rejectContentDownload(.keepAll))
    }
    
    // What happens when a file locally marked as deleted gets downloaded again, because someone else did an upload undeletion? Have we covered that case? We ought to get a `syncServerSingleFileDownloadComplete` delegate callback. Need to make sure of that.
    func testLocalDeletionDownloadedAgainBecauseUndeleted() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload the file.
        guard let (url, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        // 2) Upload delete the file
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self

        let done = self.expectation(description: "done")

        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.delete(fileWithUUID: attr.fileUUID)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        // 3) "Someone else" do an upload undeletion-- do this using the Server API directly.
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadFile(fileURL:url as URL, mimeType: attr.mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: attr.fileUUID, serverMasterVersion: masterVersion, fileVersion: 1, undelete: true) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 4) So we're ready: Locally, we've deleted the file. On the server, the file has been undeleted. We should get an event indicating the file has been downloaded. And after, I'd expect the file to not be marked as deleted in our local directory.
        
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        let done2 = self.expectation(description: "done2")
        let downloadedFileExp = self.expectation(description: "downloadedFileExp")

        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                done2.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                downloadedFileExp.fulfill()
            }
            else {
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let result = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(!result.deletedLocally)
        }
    }
    
    func testFileDownloadConflictRejectRemoveAllAndUploadNewFile() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let uploadResolution:ContentDownloadResolution.UploadResolution = .removeAll
        let resolution = ContentDownloadResolution.rejectContentDownload(uploadResolution)
        
        let numberSyncDoneExpected = 2
        var actualNumberSyncDone = 0
        
        let conflictTypeExpected:
            ConflictingClientOperation = .contentUpload(.file)
    
        let mimeType:MimeType = .text
        let fileURL = SMRelativeLocalURL(withRelativePath: "UploadMe.txt", toBaseURLType: .mainBundle)!
        
        // 1) Upload a file, not using the sync system.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let file = uploadFile(fileURL:fileURL as URL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        // 2) Setup our callbacks & expectations
        let done = self.expectation(description: "done")
        let fileUploadExp = self.expectation(description: "fileUploadExp")

        SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted]
        SyncServer.session.delegate = self
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                actualNumberSyncDone += 1
                if actualNumberSyncDone == numberSyncDoneExpected {
                    done.fulfill()
                }
                
            case .contentUploadsCompleted(let num):
                Log.msg("uploadResolution: \(String(describing: uploadResolution))")
                XCTAssert(num == 1)
                fileUploadExp.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        syncServerMustResolveContentDownloadConflict = { (content: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) in
        
            guard case .file = content else {
                XCTFail()
                return
            }
            
            XCTAssert(downloadedContentAttributes.fileUUID == file.fileUUID)
            XCTAssert(downloadedContentAttributes.mimeType == mimeType)
            
            // Do another upload-- to compensate for deleting both the upload and download.
            do {
                try SyncServer.session.uploadImmutable(localFile: fileURL, withAttributes: downloadedContentAttributes)
            }
            catch {
                XCTFail()
                uploadConflict.resolutionCallback(resolution)
                return
            }
            
            try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            
            XCTAssert(uploadConflict.conflictType == conflictTypeExpected)
            uploadConflict.resolutionCallback(resolution)
        }
        
        let attr = SyncAttributes(fileUUID: file.fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType)
        try! SyncServer.session.uploadImmutable(localFile: fileURL, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
   // Version 1 upload of a file gets access to original appMetaData in the callback, when uploaded with nil appMetaData (which doesn't change the app meta data).
    func testCallbackHasOrignalAppMetaData() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        
        // The meta data in attr1 is explicitly supposed to be nil.
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
       
        let appMetaData = "123themetadata"
        
        guard let (_, _) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, fileURL: url1, appMetaData: appMetaData) else {
            XCTFail()
            return
        }

        SyncServer.session.eventsDesired = [.syncDone, .singleFileUploadComplete]
        let expectSyncDone = self.expectation(description: "expectSyncDone")
        let expectSingleUploadComplete = self.expectation(description: "expectSingleUploadComplete")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectSyncDone.fulfill()
            
            case .singleFileUploadComplete(let attr):
                XCTAssert(attr.appMetaData == appMetaData)
                expectSingleUploadComplete.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url1, withAttributes: attr1)
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    // When a new version of a file is downloaded, do we get its new appMetaData?
    func testDownloadNewFileVersionGetAppMetaData() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // 1) Upload first version
        let url1 = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        
        // The meta data in attr1 is explicitly supposed to be nil.
        let appMetaData1 = "123themetadata"
        
        guard let (_, _) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, fileURL: url1, appMetaData: appMetaData1) else {
            XCTFail()
            return
        }
        
        // 2) Upload second version, using API so it's like another app did it.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileVersion:FileVersionInt = 1
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        let appMetaData2 = AppMetaData(version: 1, contents: "OtherAppMetaData")
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, serverMasterVersion: masterVersion, appMetaData:appMetaData2, fileVersion: fileVersion) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        // 3) Initiate the download of new version, using sync.
        SyncServer.session.eventsDesired = [.syncDone]
        let expectSyncDone = self.expectation(description: "test1")
        let expectDownload = self.expectation(description: "test2")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectSyncDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                let attr = group[0].attr
                XCTAssert(attr.appMetaData == appMetaData2.contents)
                expectDownload.fulfill()
            }
            else {
                XCTFail()
            }
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        // 4) Make sure the directory has the same appMetaData
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let directoryEntries = DirectoryEntry.fetchAll().filter {entry in
                entry.fileUUID == fileUUID1
            }
            
            guard directoryEntries.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(directoryEntries[0].appMetaData == appMetaData2.contents)
            XCTAssert(directoryEntries[0].appMetaDataVersion == appMetaData2.version)
        }
    }
    
    // Two download deletions in the same file group. File upload conflict. Client resolves conflict with `.rejectDownloadDeletion(.keepContentUpload))`
    func testTwoDownloadDeletionsInSameFileGroup() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload files
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        let fileGroupUUID = UUID().uuidString
        
        guard let (_, _) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1, fileGroupUUID: fileGroupUUID, fileURL: url) else {
            XCTFail()
            return
        }
        
        guard let (_, _) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2, fileGroupUUID: fileGroupUUID, fileURL: url) else {
            XCTFail()
            return
        }
        
        // Delete them.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let fileToDelete1 = ServerAPI.FileToDelete(fileUUID: fileUUID1, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete1, masterVersion: masterVersion)
        let fileToDelete2 = ServerAPI.FileToDelete(fileUUID: fileUUID2, fileVersion: 0, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete2, masterVersion: masterVersion)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 2)

        // Initiate an upload to create the conflict.
        
        let attr1 = SyncAttributes(fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        let attr2 = SyncAttributes(fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        SyncServer.session.eventsDesired = [.syncDone]
        let expectSyncDone = self.expectation(description: "test1")
        let expectConflicts = self.expectation(description: "test2")
        var numberSyncDone = 0
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                numberSyncDone += 1
                if numberSyncDone == 2 {
                    expectSyncDone.fulfill()
                }
                
            default:
                XCTFail()
            }
        }
        
        syncServerFileGroupDownloadComplete = { group in
            // We don't get the download deletion for the second file because (a) we are using a file group, and (b) we selected .rejectDownloadDeletion-- which operates across the file group.
            XCTFail()
        }
        
        syncServerMustResolveDownloadDeletionConflicts = { conflicts in
            guard conflicts.count == 1 else {
                XCTFail()
                return
            }
            
            let conflict = conflicts[0]
            
            guard case .contentUpload(.file)? = conflict.uploadConflict.conflictType else {
                XCTFail()
                return
            }
            
            conflict.uploadConflict.resolveConflict(resolution:
                .rejectDownloadDeletion(.keepContentUpload))
            
            DispatchQueue.main.async {
                /* This file won't be deleted locally yet. But, it will be marked as deleted on the server. How do we trigger an undeletion? It seems like we want to allow the client to trigger an undeletion. I'm not sure I want to get that power to clients though...
                Possibilities:
                1) Add a parameter to SyncAttributes-- for undeletion-- applicable only for file uploads.
                2) Add some state to the DirectoryEntry -- and when a undeletion is marked in a uft, the other directory entries in the group (if any) can be marked as pending undeletion. Which will indicate on the next file upload, that they should be undeleted. Using `deletedOnServer` for this purpose.
                */
                try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr2)
                try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
            }
            
            expectConflicts.fulfill()
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr1)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let file1 = fileIndex.filter {$0.fileUUID == attr1.fileUUID}
        guard file1.count == 1, file1[0].deleted == false else {
            XCTFail()
            return
        }
        
        let file2 = fileIndex.filter {$0.fileUUID == attr2.fileUUID}
        guard file2.count == 1, file2[0].deleted == false else {
            XCTFail()
            return
        }
    }
}
