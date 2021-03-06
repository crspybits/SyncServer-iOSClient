//
//  TestCase.swift
//  SyncServer
//
//  Created by Christopher Prince on 1/31/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
import Foundation
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class TestCase: XCTestCase {
    // Before you run any tests, change this to the account type that you want to test.
    // For Google, before running each complete set of tests, you must copy the access token from a recent sign-in (i.e., immediately before the tests) in to the .plist file.
    // For Facebook, before running each complete set of tests, you must have a long-lived access token in the .plist that is current (i.e., within the last 60 days).
    // For Dropbox, just use an access token-- they live until revoked.
    static var currTestAccount:TestAccount = .google
    
    func currTestAccountIsSharing() -> Bool {
        return TestCase.currTestAccount.accountType == ServerConstants.AuthTokenType.FacebookToken
    }
    
    struct TestAccount {
        let tokenKey:String // key into the Consts.serverPlistFile
        let accountType:ServerConstants.AuthTokenType
        
        // Only used by Dropbox
        let accountIdKey:String?
        
        // Must reference an owning account or a sharing account with admin sharing permission (the latter hasn't yet been tested).
        static let google = TestAccount(tokenKey: "GoogleAccessToken", accountType: .GoogleToken, accountIdKey:nil)
            
        // The tokenKey references a long-lived access token. It must reference a Facebook account that has admin sharing permission
        static let facebook = TestAccount(tokenKey: "FacebookAccessToken", accountType: .FacebookToken, accountIdKey:nil)
        
        static let dropbox = TestAccount(tokenKey: "DropboxAccessToken", accountType: .DropboxToken, accountIdKey: "DropboxAccountId")
            
        func token() -> String {
            let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
            
            if case .stringValue(let value) = try! plist.getRequired(varName: tokenKey) {
                return value
            }
            
            XCTFail()
            return ""
        }
        
        // Only used by Dropbox
        func accountId() -> String {
            let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
            
            if case .stringValue(let value) = try! plist.getRequired(varName: accountIdKey!) {
                return value
            }
            
            XCTFail()
            return ""
        }
    }
    
    let cloudFolderName = "Test.Folder"
    var authTokens = [String:String]()
    
    var deviceUUID = Foundation.UUID()
    var deviceUUIDUsed:Bool = false
    
    var testLockSync: TimeInterval?
    var fileIndexServerSleep: TimeInterval?
    var testLockSyncCalled:Bool = false
    
    var syncServerEventOccurred: (SyncEvent) -> () = {event in }
    var syncServerErrorOccurred: (SyncServerError) -> () = { error in
        Log.error("syncServerErrorOccurred: \(error)")
    }
        
    var syncServerMustResolveDownloadDeletionConflicts:((_ conflicts:[DownloadDeletionConflict])->())?
    var syncServerMustResolveContentDownloadConflict:((_ content: ServerContentType, _ downloadedContentAttributes: SyncAttributes, _ uploadConflict: SyncServerConflict<ContentDownloadResolution>)->())?

    var syncServerFileGroupDownloadComplete: (([DownloadOperation])->())!
    var syncServerFileGroupDownloadGone: (([DownloadOperation])->())!

    var syncServerSharingGroupsDownloaded: ((_ created: [SyncServer.SharingGroup], _ updated: [SyncServer.SharingGroup], _ deleted: [SyncServer.SharingGroup])->())?

    override func setUp() {
        super.setUp()
        ServerAPI.session.delegate = self
        ServerNetworking.session.delegate = self
        
        self.authTokens = [
            ServerConstants.XTokenTypeKey: TestCase.currTestAccount.accountType.rawValue,
            ServerConstants.HTTPOAuth2AccessTokenKey: TestCase.currTestAccount.token()
        ]
        
        if TestCase.currTestAccount.accountType == ServerConstants.AuthTokenType.DropboxToken {
            self.authTokens[ServerConstants.HTTPAccountIdKey] = TestCase.currTestAccount.accountId()
        }
        
        SyncManager.session.delegate = self
        fileIndexServerSleep = nil
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func delay(duration: Float = 3) {
        let exp = self.expectation(description: "exp")
        TimedCallback.withDuration(duration) {
            exp.fulfill()
        }
        waitForExpectations(timeout: TimeInterval(duration * 2), handler: nil)
    }

    
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
    
    func assertUploadTrackersAreReset() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let uploadTrackers = UploadFileTracker.fetchAll()
            guard uploadTrackers.count == 0 else {
                XCTFail()
                return
            }
            
            let sharingTrackers = SharingGroupUploadTracker.fetchAll()
            guard sharingTrackers.count == 0 else {
                XCTFail()
                return
            }
            
            let queues = UploadQueue.fetchAll()
            guard queues.count <= 1 else {
                XCTFail()
                return
            }
            
            if queues.count == 1 {
                guard queues[0].uploadTrackers.count == 0 else {
                    XCTFail()
                    return
                }
            }
        }
    }
    
    func assertThereIsNoTrackingMetaData(sharingGroupUUIDs: [String] = []) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(UploadQueue.fetchAll().count <= 1)
            XCTAssert(UploadQueues.fetchAll().count == 0 || Upload.synced().queues!.count == 0)
            
            XCTAssert(try! Upload.pendingSync().uploads!.count == 0)
            
            sharingGroupUUIDs.forEach { sharingGroupUUID in
                XCTAssert(Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID) == nil)
            }
            
            XCTAssert(DownloadFileTracker.fetchAll().count == 0)
            XCTAssert(DownloadContentGroup.fetchAll().count == 0)
            XCTAssert(UploadFileTracker.fetchAll().count == 0)
            XCTAssert(NetworkCached.fetchAll().count == 0)
            XCTAssert(SharingGroupUploadTracker.fetchAll().count == 0)
        }
    }
    
    func assertThereIsNoMetaData(sharingGroupUUIDs: [String]) {
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: sharingGroupUUIDs)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(DirectoryEntry.fetchAll().count == 0)
        }
    }
    
    func setupTest(removeServerFiles:Bool=true, actualDeletion:Bool=true) {
        if !updateSharingGroupsWithSync() {
            XCTFail()
        }
        
        resetFileMetaData(removeServerFiles: removeServerFiles, actualDeletion: actualDeletion)
        
        if !updateSharingGroupsWithSync() {
            XCTFail()
        }
        
        print("Test")
    }
    
    @discardableResult
    func updateSharingGroupsWithSync() -> Bool {
        var result = false

        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        
        let syncDone = self.expectation(description: "testUpdateSharingGroupsWithSync")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                result = true
                syncDone.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        syncServerErrorOccurred = { error in
            XCTFail("error: \(error)")
            syncDone.fulfill()
        }
        
        try! SyncServer.session.sync()
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return result
    }
    
    func getLocalMasterVersionFor(sharingGroupUUID: String) -> MasterVersionInt? {
        var result: MasterVersionInt?
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
        
            result = sharingEntry.masterVersion
        }
        
        return result
    }

    @discardableResult
    func incrementMasterVersionFor(sharingGroupUUID: String) -> Bool {
        var result = false
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
        
            sharingEntry.masterVersion += 1
            result = true
        }
        
        return result
    }
    
    @discardableResult
    func decrementMasterVersionFor(sharingGroupUUID: String) -> Bool {
        var result = false
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                XCTFail()
                return
            }
        
            sharingEntry.masterVersion -= 1
            result = true
        }
        
        return result
    }
    
    func createSharingGroup(sharingGroupUUID: String, sharingGroupName: String?) -> Bool {
        let expectation = self.expectation(description: "testCreateSharingGroup")

        var sharingGroupResult:Bool = false
        
        ServerAPI.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: sharingGroupName) { error in
            if error == nil {
                sharingGroupResult = true
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        return sharingGroupResult
    }
    
    // nil is the expected result
    func updateSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt, sharingGroupName: String) -> MasterVersionInt? {
        let expectation = self.expectation(description: "testUpdateSharingGroup")

        var masterVersionUpdate:MasterVersionInt?

        ServerAPI.session.updateSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: masterVersion, sharingGroupName: sharingGroupName) { response in
            switch response {
            case .success(let result):
                masterVersionUpdate = result
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        return masterVersionUpdate
    }
    
    // nil is the expected result
    func removeSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt) -> MasterVersionInt? {
        let expectation = self.expectation(description: "testRemoveSharingGroup")

        var masterVersionUpdate:MasterVersionInt?
        
        ServerAPI.session.removeSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: masterVersion) { response in
            switch response {
            case .success(let result):
                masterVersionUpdate = result
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        return masterVersionUpdate
    }
    
    // nil is the expected result
    func removeUserFromSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt) -> MasterVersionInt? {
        let expectation = self.expectation(description: "testRemoveUserFromSharingGroup")

        var masterVersionUpdate:MasterVersionInt?
        
        ServerAPI.session.removeUserFromSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: masterVersion) { response in
            switch response {
            case .success(let result):
                masterVersionUpdate = result
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
        
        return masterVersionUpdate
    }
    
    func getFirstSharingGroup() -> SyncServer.SharingGroup? {
        let sharingGroups = SyncServer.session.sharingGroups
        guard sharingGroups.count > 0 else {
            XCTFail()
            return nil
        }
        
        return sharingGroups[0]
    }
    
    func getSharingGroups() -> [SyncServer.SharingGroup]? {
        let sharingGroups = SyncServer.session.sharingGroups        
        return sharingGroups
    }
    
    @discardableResult
    func uploadFileVersion(_ version:FileVersionInt, fileURL: URL, mimeType:MimeType, sharingGroupUUID: String, fileGroupUUID: String? = nil) -> ServerAPI.File? {
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        var fileVersion:FileVersionInt = 0
        let fileUUID = UUID().uuidString
    
        guard let fileResult = uploadFile(fileURL:fileURL, mimeType: mimeType,  sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return nil
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
    
        var resultFile:ServerAPI.File?
        
        while fileVersion < version {
            masterVersion += 1
            fileVersion += 1
        
            guard let file = uploadFile(fileURL:fileURL, mimeType: mimeType,  sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, fileVersion: fileVersion, fileGroupUUID: fileGroupUUID) else {
                XCTFail()
                return nil
            }
            
            resultFile = file
            
            doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        }
        
        guard let file = resultFile else {
            XCTFail()
            return nil
        }
    
        guard let getFileResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex:[FileInfo] = getFileResult.fileIndex else {
            XCTFail()
            return nil
        }
        
        let result = fileIndex.filter({$0.fileUUID == fileUUID})
        guard result.count == 1 else {
            XCTFail()
            return nil
        }

        XCTAssert(result[0].fileVersion == fileVersion)
        XCTAssert(result[0].deviceUUID == file.deviceUUID)
        XCTAssert(result[0].fileGroupUUID == file.fileGroupUUID)
        
        if let resultMimeTypeString = result[0].mimeType {
            let resultMimeType = MimeType(rawValue: resultMimeTypeString)
            XCTAssert(resultMimeType == file.mimeType)
        }
        else {
            XCTFail()
        }
        
        onlyDownloadFile(comparisonFileURL: fileURL, file: file, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: nil)
        
        return fileResult
    }
    
    typealias FileUUIDURL = (uuid: String, url: URL)
    func findAndRemoveFile(uuid: String, url: URL, in files: inout [FileUUIDURL]) -> Bool {
        guard let fileIndex = files.index(where: {$0.uuid == uuid}) else {
            return false
        }

        let result = FilesMisc.compareFiles(file1: files[fileIndex].url, file2: url as URL)
        files.remove(at: fileIndex)

        return result
    }
    
    func getMasterVersion(sharingGroupUUID: String) -> MasterVersionInt? {
        let expectation1 = self.expectation(description: "fileIndex")

        var serverMasterVersion:MasterVersionInt?
        
        ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
            switch response {
            case .success(let result):
                serverMasterVersion = result.masterVersion
            case .error:
                XCTFail()
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return serverMasterVersion
    }
    
    @discardableResult
    func getFileIndex(sharingGroupUUID: String? = nil, expectedFileUUIDs:[String] = [], errorExpected: Bool = false, callback:((FileInfo)->())? = nil) -> ServerAPI.IndexResult? {
        let expectation1 = self.expectation(description: "fileIndex")
        
        var fileInfoResult: ServerAPI.IndexResult?
        
        ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
            switch response {
            case .success(let result):
                if errorExpected {
                    XCTFail()
                    expectation1.fulfill()
                    return
                }
                fileInfoResult = result

            case .error:
                if !errorExpected {
                    XCTFail()
                }
                expectation1.fulfill()
                return
            }
            
            for fileUUID in expectedFileUUIDs {
                let result = fileInfoResult?.fileIndex?.filter { file in
                    file.fileUUID == fileUUID
                }
                
                guard result!.count == 1 else {
                    XCTFail("result!.count= \(result!.count)")
                    fileInfoResult = nil
                    return
                }
            
                XCTAssert(result![0].cloudStorageType != nil)
            }
            
            if let fileIndex = fileInfoResult?.fileIndex {
                for curr in 0..<fileIndex.count {
                    callback?(fileIndex[curr])
                }
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        return fileInfoResult
    }
    
    func getUploads(sharingGroupUUID: String, expectedFileUUIDs:[String], callback:((FileInfo)->())? = nil) {
        let expectation1 = self.expectation(description: "getUploads")
        
        ServerAPI.session.getUploads(sharingGroupUUID: sharingGroupUUID) { (uploads, error) in
            XCTAssert(error == nil)
            
            XCTAssert(expectedFileUUIDs.count == uploads?.count)
            
            for fileUUID in expectedFileUUIDs {
                let result = uploads?.filter { file in
                    file.fileUUID == fileUUID
                }
                
                XCTAssert(result!.count == 1)
                // FileInfo objects don't have cloud storage type when returned from GetUploads
                XCTAssert(result![0].cloudStorageType == nil)
            }
            
            for curr in 0..<uploads!.count {
                callback?(uploads![curr])
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    // Returns the file size uploaded
    @discardableResult
    func uploadFile(fileURL:URL, mimeType:MimeType, sharingGroupUUID: String, fileUUID:String? = nil, serverMasterVersion:MasterVersionInt = 0, expectError:Bool = false, appMetaData:AppMetaData? = nil, theDeviceUUID:String? = nil, fileVersion:FileVersionInt = 0, undelete: Bool = false, fileGroupUUID:String? = nil, useCheckSum: String? = nil, expectUploadGone: GoneReason? = nil) -> ServerAPI.File? {

        var uploadFileUUID:String
        if fileUUID == nil {
            uploadFileUUID = UUID().uuidString
        } else {
            uploadFileUUID = fileUUID!
        }
        
        var finalDeviceUUID:String
        if theDeviceUUID == nil {
            finalDeviceUUID = deviceUUID.uuidString
        }
        else {
            finalDeviceUUID = theDeviceUUID!
        }

        var uploadCheckSum: String!
        
        if let useCheckSum = useCheckSum {
            uploadCheckSum = useCheckSum
        }
        else {
            guard let cloudStorageType = TestCase.currTestAccount.accountType.toCloudStorageType() else {
                XCTFail()
                return nil
            }
            
            guard let checkSum = Hashing.hashOf(url: fileURL, for: cloudStorageType) else {
                XCTFail()
                return nil
            }
            
            uploadCheckSum = checkSum
        }

        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, fileGroupUUID: fileGroupUUID, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType, deviceUUID: finalDeviceUUID, appMetaData: appMetaData, fileVersion: fileVersion, checkSum: uploadCheckSum)
        
        let expectation = self.expectation(description: "upload")

        ServerAPI.session.uploadFile(file: file, serverMasterVersion: serverMasterVersion, undelete: undelete) { uploadFileResult, error in
            if let expectUploadGone = expectUploadGone,
                let uploadFileResult = uploadFileResult {
                switch uploadFileResult {
                case .gone(let goneReason):
                    XCTAssert(expectUploadGone == goneReason)
                default:
                    XCTFail()
                }
            }
            else if expectError {
                XCTAssert(error != nil)
            }
            else {
                XCTAssert(error == nil)
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        return file
    }
    
    func uploadFile(fileName:String, fileExtension:String, sharingGroupUUID: String, mimeType:MimeType, fileUUID:String? = nil, serverMasterVersion:MasterVersionInt = 0, withExpectation expectation:XCTestExpectation) {
    
        var uploadFileUUID:String
        if fileUUID == nil {
            uploadFileUUID = UUID().uuidString
        }
        else {
            uploadFileUUID = fileUUID!
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!
        
        guard let signIn = SignInManager.session.currentSignIn,
            signIn.userType == .owning,
            let cloudStorageType = signIn.cloudStorageType else {
            XCTFail()
            return
        }
        
        guard let checkSum = Hashing.hashOf(url: fileURL, for: cloudStorageType) else {
            XCTFail()
            return
        }

        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, fileGroupUUID: nil, sharingGroupUUID: sharingGroupUUID, mimeType: mimeType, deviceUUID: deviceUUID.uuidString, appMetaData: nil, fileVersion: 0, checkSum: checkSum)
        
        Log.special("ServerAPI.session.uploadFile")
        
        ServerAPI.session.uploadFile(file: file, serverMasterVersion: serverMasterVersion) { uploadFileResult, error in
            XCTAssert(error == nil, "\(String(describing: error))")
            expectation.fulfill()
        }
    }
    
    func doneUploads(masterVersion: MasterVersionInt,  sharingGroupUUID: String, expectedNumberUploads:Int64=0, expectedNumberDeletions:UInt=0) {
    
        let expectedNumber = expectedNumberUploads + Int64(expectedNumberDeletions)
        if expectedNumber <= 0 {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "doneUploads")

        ServerAPI.session.doneUploads(serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, numberOfDeletions: expectedNumberDeletions) {
            doneUploadsResult, error in
            
            XCTAssert(error == nil)
            if case .success(let numberUploads) = doneUploadsResult! {
                XCTAssert(numberUploads == expectedNumber, "Didn't get the number of uploads \(numberUploads) we expected \(expectedNumber)")
            }
            else {
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: Double(expectedNumber)*20.0, handler: nil)
    }
    
    func removeAllServerFilesInFileIndex(sharingGroupUUID: String, actualDeletion:Bool=true) {
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        var filesToDelete:[FileInfo]?
        let uploadDeletion = self.expectation(description: "uploadDeletion")

        func recursiveRemoval(indexToRemove:Int) {
            guard filesToDelete != nil else {
                XCTFail()
                uploadDeletion.fulfill()
                return
            }
            
            if indexToRemove >= filesToDelete!.count {
                uploadDeletion.fulfill()
                return
            }
            
            let fileIndexObj = filesToDelete![indexToRemove]
            var fileToDelete = ServerAPI.FileToDelete(fileUUID: fileIndexObj.fileUUID, fileVersion: fileIndexObj.fileVersion, sharingGroupUUID: sharingGroupUUID)
            
            fileToDelete.actualDeletion = actualDeletion
            
            ServerAPI.session.uploadDeletion(file: fileToDelete, serverMasterVersion: masterVersion) { (result, error) in
                XCTAssert(error == nil)
                guard case .success = result! else {
                    XCTFail("\(String(describing: error)); result: \(String(describing: result))")
                    return
                }
                
                recursiveRemoval(indexToRemove: indexToRemove + 1)
            }
        }
        
        var numberDeletions:Int!
        
        ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
            switch response {
            case .success(let result):
                if actualDeletion {
                    filesToDelete = result.fileIndex
                }
                else {
                    filesToDelete =  result.fileIndex!.filter({$0.deleted! == false})
                }
            case .error(let error):
                XCTFail("\(error)")
            }

            numberDeletions = filesToDelete?.count
            
            recursiveRemoval(indexToRemove: 0)
        }
        
        waitForExpectations(timeout: 120.0, handler: nil)
        
        guard numberDeletions != nil else {
            XCTFail()
            return
        }
        
        // actual deletion removes actual rows from the file index-- in which case we don't need the done uploads to wrap things up.
        if numberDeletions! > 0 && !actualDeletion {
            doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberDeletions: UInt(numberDeletions!))
        }
    }

    @discardableResult
    func uploadAppMetaData(masterVersion: MasterVersionInt, appMetaData: AppMetaData, fileUUID: String, sharingGroupUUID: String, failureExpected: Bool = false) -> Bool {
        let exp = self.expectation(description: "exp")
        var result = true
        
        ServerAPI.session.uploadAppMetaData(appMetaData: appMetaData, fileUUID: fileUUID, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) { serverResult in
            switch serverResult {
            case .success(.success):
                if failureExpected {
                    XCTFail()
                    result = false
                }
                
            case .success(.serverMasterVersionUpdate(_)):
                if !failureExpected {
                    XCTFail()
                    result = false
                }
                
            case .error:
                if !failureExpected {
                    XCTFail()
                    result = false
                }
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        return result
    }
    
    @discardableResult
    func downloadAppMetaData(masterVersion: MasterVersionInt, appMetaDataVersion: AppMetaDataVersionInt, fileUUID: String,  sharingGroupUUID: String, failureExpected: Bool = false) -> String? {
        let exp = self.expectation(description: "exp")
        var result:String?
        
        ServerAPI.session.downloadAppMetaData(appMetaDataVersion: appMetaDataVersion, fileUUID: fileUUID, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) { serverResult in
            switch serverResult {
            case .success(.appMetaData(let appMetaData)):
                if failureExpected {
                    XCTFail()
                }
                else {
                    result = appMetaData
                }
                
            case .success(.serverMasterVersionUpdate(_)):
                if !failureExpected {
                    XCTFail()
                }
                
            case .error:
                if !failureExpected {
                    XCTFail()
                }
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        return result
    }
    
    func filesHaveSameContents(url1: URL, url2: URL) -> Bool {
        let fileData1 = try? Data(contentsOf: url1 as URL)
        let fileData2 = try? Data(contentsOf: url2 as URL)
        
        if fileData1 == nil || fileData2 == nil {
            return false
        }
        
        return fileData1! == fileData2!
    }

    @discardableResult
    // Uses SyncManager.session.start
    func uploadAndDownloadOneFileUsingStart( sharingGroupUUID: String) -> (ServerAPI.File, MasterVersionInt)? {
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        let expectedFiles = [file]
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file(let url, let contentsChanged) = group[0].type {
                XCTAssert(!contentsChanged)
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                XCTAssert(self.filesHaveSameContents(url1: file.localURL, url2: url as URL))
            }
            else {
                XCTFail()
            }
        }
        
        let expectation = self.expectation(description: "start")

        SyncManager.session.start(sharingGroupUUID: sharingGroupUUID) { (error) in
            XCTAssert(error == nil)
            XCTAssert(downloadCount == 1)
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                let entries = DirectoryEntry.fetchAll()
                
                // There may be more directory entries than just accounted for in this single function call, so don't do this:
                // XCTAssert(entries.count == expectedFiles.count)

                for file in expectedFiles {
                    let entriesResult = entries.filter { $0.fileUUID == file.fileUUID &&
                        $0.fileVersion == file.fileVersion
                    }
                    XCTAssert(entriesResult.count == 1)
                }
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 30.0, handler: nil)
        
        return (file, masterVersion + 1)
    }

    @discardableResult
    func uploadDeletion( sharingGroupUUID: String) -> (fileUUID:String, MasterVersionInt)? {
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let file = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion, sharingGroupUUID: sharingGroupUUID)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
        
        getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID
        ]) { fileInfo in
            XCTAssert(fileInfo.deleted)
        }
        
        return (fileUUID, masterVersion+1)
    }
    
    func uploadDeletionOfOneFileWithDoneUploads(sharingGroupUUID: String) {
        guard let (fileUUID, masterVersion) = uploadDeletion(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        self.doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        self.getUploads(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: []) { file in
            XCTAssert(file.fileUUID != fileUUID)
        }
        
        var foundDeletedFile = false
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, expectedFileUUIDs: [
            fileUUID
        ]) { file in
            if file.fileUUID == fileUUID {
                foundDeletedFile = true
                XCTAssert(file.deleted)
            }
        }
        
        XCTAssert(foundDeletedFile)
    }
    
    func uploadAndDownloadFile(sharingGroupUUID: String, appMetaData:AppMetaData? = nil, uploadFileURL:URL, mimeType: MimeType, fileUUID:String? = nil) {
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        var actualFileUUID:String! = fileUUID
        if fileUUID == nil {
            actualFileUUID = UUID().uuidString
        }
        
        guard let file = uploadFile(fileURL:uploadFileURL, mimeType: mimeType,  sharingGroupUUID: sharingGroupUUID, fileUUID: actualFileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        onlyDownloadFile(comparisonFileURL: uploadFileURL, file: file, masterVersion: masterVersion + 1, sharingGroupUUID: sharingGroupUUID, appMetaData: appMetaData)
    }
    
    func uploadAndDownloadTextFile(sharingGroupUUID: String, appMetaData:AppMetaData? = nil, uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!, fileUUID:String? = nil) {
    
        uploadAndDownloadFile(sharingGroupUUID: sharingGroupUUID, appMetaData:appMetaData, uploadFileURL:uploadFileURL, mimeType: .text, fileUUID:fileUUID)
    }
    
    func onlyDownloadFile(comparisonFileURL:URL, file:Filenaming, masterVersion:MasterVersionInt, sharingGroupUUID: String, appMetaData:AppMetaData? = nil, expectedCheckSum:String? = nil) {
        let expectation = self.expectation(description: "download")

        let fileNamingObj = FilenamingWithAppMetaDataVersion(fileUUID: file.fileUUID, fileVersion: file.fileVersion, appMetaDataVersion: appMetaData?.version)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) { (result, error) in
            
            guard let result = result, error == nil else {
                XCTFail()
                return
            }
            
            if case .success(let downloadedFile) = result {
                switch downloadedFile {
                case .gone:
                    XCTFail()
                case .content(url: let url, appMetaData: let contentAppMetaData, checkSum: let checkSum, cloudStorageType: _, contentsChangedOnServer: _):
                
                    XCTAssert(FilesMisc.compareFiles(file1: comparisonFileURL, file2: url as URL))
                    if appMetaData != nil {
                        XCTAssert(contentAppMetaData == appMetaData)
                    }
                    if let expectedCheckSum = expectedCheckSum {
                        XCTAssert(expectedCheckSum == checkSum)
                    }
                }
            }
            else {
                XCTFail("\(result)")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    enum UploadSingleFileUsingSyncError {
        case uploadImmutable
    }
    
    @discardableResult
    func uploadSingleFileUsingSync(sharingGroupUUID: String, fileUUID:String = UUID().uuidString, fileGroupUUID: String? = nil, fileURL:SMRelativeLocalURL? = nil, mimeType: MimeType = .text, appMetaData:String? = nil, uploadCopy:Bool = false, sharingGroupOperationExpected: Bool = false, errorExpected: UploadSingleFileUsingSyncError? = nil) -> (SMRelativeLocalURL, SyncAttributes)? {
        
        var url:SMRelativeLocalURL
        var originalURL:SMRelativeLocalURL
        let actualMimeType: MimeType
        
        if fileURL == nil {
            url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
            actualMimeType = .text
        }
        else {
            url = fileURL!
            actualMimeType = mimeType
        }
        
        originalURL = url
        
        if uploadCopy {
            // In exercising the `copy` characteristics, we're going to delete the file immediately after uploadCopy. So, make a copy now since we can't delete a bundle file.
            guard let copyOfFileURL = FilesMisc.newTempFileURL() else {
                XCTFail()
                return nil
            }
            
            try! FileManager.default.copyItem(at: url as URL, to: copyOfFileURL as URL)
            url = copyOfFileURL
        }

        var attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: actualMimeType)
        attr.appMetaData = appMetaData
        attr.fileGroupUUID = fileGroupUUID
        
        SyncServer.session.delegate = self

        if sharingGroupOperationExpected {
            SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete,
                    .sharingGroupUploadOperationCompleted]
        }
        else {
            SyncServer.session.eventsDesired = [.syncDone, .contentUploadsCompleted, .singleFileUploadComplete]
        }
        
        var expectation1:XCTestExpectation!
        var expectation2:XCTestExpectation!
        var expectation3:XCTestExpectation!
        var expectation4:XCTestExpectation!

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .contentUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation2.fulfill()
                
            case .singleFileUploadComplete(attr: let attr):
                XCTAssert(attr.fileUUID == fileUUID)
                XCTAssert(attr.mimeType == actualMimeType)
                expectation3.fulfill()
                
            case .sharingGroupUploadOperationCompleted:
                expectation4.fulfill()
                
            default:
                XCTFail()
            }
        }

        if uploadCopy {
            try! SyncServer.session.uploadCopy(localFile: url, withAttributes: attr)
            // To truly exercise the `copy` characteristics-- delete the file now.
            try! FileManager.default.removeItem(at: url as URL)
        }
        else {
            do {
                try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
                if errorExpected == UploadSingleFileUsingSyncError.uploadImmutable {
                    XCTFail()
                    return nil
                }
            } catch (let error) {
                if errorExpected != UploadSingleFileUsingSyncError.uploadImmutable {
                    XCTFail("\(error)")
                }
                return nil
            }
        }
        
        expectation1 = self.expectation(description: "test1")
        expectation2 = self.expectation(description: "test2")
        expectation3 = self.expectation(description: "test3")
        
        if sharingGroupOperationExpected {
            expectation4 = self.expectation(description: "test4")
        }
        
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        return (originalURL, attr)
    }
    
    // actualDeletion only applies if removeServerFiles is true.
    func resetFileMetaData(removeServerFiles:Bool=true, actualDeletion:Bool=true) {
        if removeServerFiles {
            guard let sharingGroups = getSharingGroups() else {
                XCTFail()
                return
            }
        
            sharingGroups.forEach { sharingGroup in
                let sharingGroupUUID = sharingGroup.sharingGroupUUID
                removeAllServerFilesInFileIndex(sharingGroupUUID: sharingGroupUUID, actualDeletion:actualDeletion)
            }
        }
        
        // Do this after any removal of server files because we need the sharing groups meta data in order to know which sharing groups we're removing files from.
        do {
            try SyncServer.resetMetaData()
        } catch {
            XCTFail()
        }
    }
    
    // returns the fileUUID
    @discardableResult
    func doASingleDownloadUsingSync(fileName: String, fileExtension:String, mimeType:MimeType,  sharingGroupUUID: String, appMetaData:AppMetaData? = nil) -> String? {
        let initialDeviceUUID = self.deviceUUID

        // First upload a file.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return nil
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!

        guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType,  sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData) else {
            return nil
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        let expectation = self.expectation(description: "test1")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                let attr = group[0].attr
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                XCTAssert(attr.appMetaData == appMetaData?.contents)
                expectation.fulfill()
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
        
        XCTAssert(initialDeviceUUID != ServerAPI.session.delegate.deviceUUID(forServerAPI: ServerAPI.session))
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        // 9/16/17; I'm getting an odd test interaction. The test immediately after this one is failing seemingly because there is a download available *after* this test. This is to check to see if somehow there is a DownloadFileTracker still available. There shouldn't be.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts.count == 0)
        }
        
        return fileUUID
    }
    
    func uploadDeletion(fileToDelete:ServerAPI.FileToDelete, masterVersion:MasterVersionInt) {
        let uploadDeletion = self.expectation(description: "uploadDeletion")

        ServerAPI.session.uploadDeletion(file: fileToDelete, serverMasterVersion: masterVersion) { (result, error) in
            XCTAssert(error == nil)
            guard case .success = result! else {
                XCTFail()
                return
            }
            uploadDeletion.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func healthCheck() -> HealthCheckResponse? {
        var result:HealthCheckResponse?
        
        let exp = self.expectation(description: "exp")

        ServerAPI.session.healthCheck { response, error in
            XCTAssert(error == nil)
            result = response
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return result
    }
}

extension TestCase : ServerNetworkingDelegate {
    func serverNetworkingServerVersion(_ version:ServerVersion?) -> Bool  {
        return true
    }
    
    func serverNetworkingMinimumIOSAppVersion(forServerNetworking: Any?, version: ServerVersion) {
    }
    
    func serverNetworkingHeaderAuthentication(forServerNetworking: Any?) -> [String:String]? {
        var result = [String:String]()
        for (key, value) in self.authTokens {
            result[key] = value
        }
        
        result[ServerConstants.httpRequestDeviceUUID] = self.deviceUUID.uuidString
        deviceUUIDUsed = true
        
#if DEBUG
        if ServerAPI.session.failNextEndpoint {
            result[ServerConstants.httpRequestEndpointFailureTestKey] = "true"
        }
#endif
        
        return result
    }
    
    func serverNetworkingFailover(forServerNetworking: Any?, message: String) {
    }
}

extension TestCase : ServerAPIDelegate {    
    func doneUploadsRequestTestLockSync(forServerAPI: ServerAPI) -> TimeInterval? {
        testLockSyncCalled = true
        return testLockSync
    }
    
    func indexRequestServerSleep(forServerAPI: ServerAPI) -> TimeInterval? {
        return fileIndexServerSleep
    }
    
    func deviceUUID(forServerAPI: ServerAPI) -> Foundation.UUID {
        return deviceUUID
    }
    
    func userWasUnauthorized(forServerAPI: ServerAPI) {
        Log.error("User was unauthorized!")
    }
}

extension TestCase : SyncServerDelegate {
    func syncServerSharingGroupsDownloaded(created: [SyncServer.SharingGroup], updated: [SyncServer.SharingGroup], deleted: [SyncServer.SharingGroup]) {
        syncServerSharingGroupsDownloaded?(created, updated, deleted)
    }
    
    func syncServerFileGroupDownloadComplete(group: [DownloadOperation]) {
        syncServerFileGroupDownloadComplete?(group)
    }
    
    func syncServerFileGroupDownloadGone(group: [DownloadOperation]) {
        syncServerFileGroupDownloadGone?(group)
    }
    
    func syncServerMustResolveContentDownloadConflict(_ content: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) {
        syncServerMustResolveContentDownloadConflict?(content, downloadedContentAttributes, uploadConflict)
    }

    func syncServerMustResolveDownloadDeletionConflicts(conflicts:[DownloadDeletionConflict]) {
        syncServerMustResolveDownloadDeletionConflicts?(conflicts)
    }
    
    func syncServerEventOccurred(event: SyncEvent) {
        syncServerEventOccurred(event)
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        syncServerErrorOccurred(error)
    }
}

