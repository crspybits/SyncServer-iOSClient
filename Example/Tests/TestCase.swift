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
    static let currTestAccount:TestAccount = .google
    
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
    
    var shouldSaveDownload: ((_ downloadedFile: NSURL, _ downloadedFileAttributes: SyncAttributes) -> ())!
    var syncServerEventOccurred: (SyncEvent) -> () = {event in }
    var shouldDoDeletions: (_ downloadDeletions: [SyncAttributes]) -> () = { downloadDeletions in }
    var syncServerErrorOccurred: (SyncServerError) -> () = { error in
        Log.error("syncServerErrorOccurred: \(error)")
    }
    
    var syncServerSingleFileUploadCompleted:((_ next: @escaping ()->())->())?
    var syncServerSingleFileDownloadCompleted:((_ url:SMRelativeLocalURL, _ attr: SyncAttributes, _ next: @escaping ()->())->())?
    
    var syncServerMustResolveDownloadDeletionConflicts:((_ conflicts:[DownloadDeletionConflict])->())?
    var syncServerMustResolveContentDownloadConflict:((_ downloadedFile: SMRelativeLocalURL?, _ downloadedContentAttributes: SyncAttributes, _ uploadConflict: SyncServerConflict<ContentDownloadResolution>)->())?
    var syncServerAppMetaDataDownloadComplete: ((SyncAttributes)->())!

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
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func assertThereIsNoMetaData() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            // Must put these three before the `Upload.pendingSync()` call which recreates the singleton and other core data objects.
            XCTAssert(UploadQueue.fetchAll().count == 0)
            XCTAssert(UploadQueues.fetchAll().count == 0)
            XCTAssert(Singleton.fetchAll().count == 0)
            
            XCTAssert(try! Upload.pendingSync().uploads!.count == 0)
            XCTAssert(Upload.getHeadSyncQueue() == nil)
            XCTAssert(DownloadFileTracker.fetchAll().count == 0)
            XCTAssert(UploadFileTracker.fetchAll().count == 0)
            XCTAssert(DirectoryEntry.fetchAll().count == 0)
        }
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
    
    func getMasterVersion() -> MasterVersionInt {
        let expectation1 = self.expectation(description: "fileIndex")

        var serverMasterVersion:MasterVersionInt = 0
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            XCTAssert(error == nil)
            XCTAssert(masterVersion! >= 0)
            serverMasterVersion = masterVersion!
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return serverMasterVersion
    }
    
    @discardableResult
    func getFileIndex(expectedFiles:[(fileUUID:String, fileSize:Int64?)] = [], callback:((FileInfo)->())? = nil) -> [FileInfo]? {
        let expectation1 = self.expectation(description: "fileIndex")
        
        var fileInfoResult: [FileInfo]?
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            XCTAssert(error == nil)
            XCTAssert(masterVersion! >= 0)
            
            fileInfoResult = fileIndex
            
            for (fileUUID, fileSize) in expectedFiles {
                let result = fileIndex?.filter { file in
                    file.fileUUID == fileUUID
                }
                
                guard result!.count == 1 else {
                    XCTFail("result!.count= \(result!.count)")
                    fileInfoResult = nil
                    return
                }
            
                if fileSize != nil {
                    guard result![0].fileSizeBytes == fileSize else {
                        XCTFail()
                        fileInfoResult = nil
                        return
                    }
                }
            }
            
            for curr in 0..<fileIndex!.count {
                callback?(fileIndex![curr])
            }
            
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        return fileInfoResult
    }
    
    func getUploads(expectedFiles:[(fileUUID:String, fileSize:Int64?)], callback:((FileInfo)->())? = nil) {
        let expectation1 = self.expectation(description: "getUploads")
        
        ServerAPI.session.getUploads { (uploads, error) in
            XCTAssert(error == nil)
            
            XCTAssert(expectedFiles.count == uploads?.count)
            
            for (fileUUID, fileSize) in expectedFiles {
                let result = uploads?.filter { file in
                    file.fileUUID == fileUUID
                }
                
                XCTAssert(result!.count == 1)
                if fileSize != nil {
                    XCTAssert(result![0].fileSizeBytes == fileSize)
                }
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
    func uploadFile(fileURL:URL, mimeType:MimeType, fileUUID:String? = nil, serverMasterVersion:MasterVersionInt = 0, expectError:Bool = false, appMetaData:AppMetaData? = nil, theDeviceUUID:String? = nil, fileVersion:FileVersionInt = 0, undelete: Bool = false) -> (fileSize: Int64, ServerAPI.File)? {

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
        
        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, mimeType: mimeType, deviceUUID: finalDeviceUUID, appMetaData: appMetaData, fileVersion: fileVersion)
        
        // Just to get the size-- this is redundant with the file read in ServerAPI.session.uploadFile
        guard let fileData = try? Data(contentsOf: file.localURL) else {
            XCTFail()
            return nil
        }
        
        let expectation = self.expectation(description: "upload")
        var fileSize:Int64?
        
        ServerAPI.session.uploadFile(file: file, serverMasterVersion: serverMasterVersion, undelete: undelete) { uploadFileResult, error in
            if expectError {
                XCTAssert(error != nil)
            }
            else {
                XCTAssert(error == nil)
                if case .success(let size, _, _) = uploadFileResult! {
                    XCTAssert(Int64(fileData.count) == size)
                    fileSize = size
                }
                else {
                    XCTFail()
                }
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        if fileSize == nil {
            return nil
        }
        else {
            return (fileSize!, file)
        }
    }
    
    func uploadFile(fileName:String, fileExtension:String, mimeType:MimeType, fileUUID:String? = nil, serverMasterVersion:MasterVersionInt = 0, withExpectation expectation:XCTestExpectation) {
    
        var uploadFileUUID:String
        if fileUUID == nil {
            uploadFileUUID = UUID().uuidString
        }
        else {
            uploadFileUUID = fileUUID!
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!

        let file = ServerAPI.File(localURL: fileURL, fileUUID: uploadFileUUID, mimeType: mimeType, deviceUUID: deviceUUID.uuidString, appMetaData: nil, fileVersion: 0)
        
        // Just to get the size-- this is redundant with the file read in ServerAPI.session.uploadFile
        guard let fileData = try? Data(contentsOf: file.localURL) else {
            XCTFail()
            return
        }
        
        Log.special("ServerAPI.session.uploadFile")
        
        ServerAPI.session.uploadFile(file: file, serverMasterVersion: serverMasterVersion) { uploadFileResult, error in
        
            if error == nil {
                if case .success(let size, _, _) = uploadFileResult! {
                    XCTAssert(Int64(fileData.count) == size)
                }
                else {
                    XCTFail()
                }
            }
            else {
                XCTFail()
            }
            
            expectation.fulfill()
        }
    }
    
    func doneUploads(masterVersion: MasterVersionInt, expectedNumberUploads:Int64=0, expectedNumberDeletions:UInt=0) {
    
        let expectedNumber = expectedNumberUploads + Int64(expectedNumberDeletions)
        if expectedNumber <= 0 {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "doneUploads")

        ServerAPI.session.doneUploads(serverMasterVersion: masterVersion, numberOfDeletions: expectedNumberDeletions) {
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
        
        waitForExpectations(timeout: Double(expectedNumber)*10.0, handler: nil)
    }
    
    func removeAllServerFilesInFileIndex(actualDeletion:Bool=true) {
        let masterVersion = getMasterVersion()
        
        var filesToDelete:[FileInfo]?
        let uploadDeletion = self.expectation(description: "uploadDeletion")

        func recursiveRemoval(indexToRemove:Int) {
            if indexToRemove >= filesToDelete!.count {
                uploadDeletion.fulfill()
                return
            }
            
            let fileIndexObj = filesToDelete![indexToRemove]
            var fileToDelete = ServerAPI.FileToDelete(fileUUID: fileIndexObj.fileUUID, fileVersion: fileIndexObj.fileVersion)
            
            fileToDelete.actualDeletion = actualDeletion
            
            ServerAPI.session.uploadDeletion(file: fileToDelete, serverMasterVersion: masterVersion) { (result, error) in
                XCTAssert(error == nil)
                guard case .success = result! else {
                    XCTFail()
                    return
                }
                
                recursiveRemoval(indexToRemove: indexToRemove + 1)
            }
        }
        
        var numberDeletions:Int!
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            
            XCTAssert(error == nil)
            XCTAssert(masterVersion! >= 0)
            
            if actualDeletion {
                filesToDelete = fileIndex
            }
            else {
                filesToDelete = fileIndex!.filter({$0.deleted! == false})
            }
            
            numberDeletions = filesToDelete?.count
            
            recursiveRemoval(indexToRemove: 0)
        }
        
        waitForExpectations(timeout: 120.0, handler: nil)
        
        // actual deletion removes actual rows from the file index-- in which case we don't need the done uploads to wrap things up.
        if numberDeletions! > 0 && !actualDeletion {
            doneUploads(masterVersion: masterVersion, expectedNumberDeletions: UInt(numberDeletions!))
        }
    }

    @discardableResult
    func uploadAppMetaData(masterVersion: MasterVersionInt, appMetaData: AppMetaData, fileUUID: String, failureExpected: Bool = false) -> Bool {
        let exp = self.expectation(description: "exp")
        var result = true
        
        ServerAPI.session.uploadAppMetaData(appMetaData: appMetaData, fileUUID: fileUUID, serverMasterVersion: masterVersion) { serverResult in
            switch serverResult {
            case .success(.success):
                if failureExpected {
                    XCTFail()
                    result = false
                }
                
            case .success(.serverMasterVersionUpdate(_)):
                XCTFail()
                result = false
                
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
    func downloadAppMetaData(masterVersion: MasterVersionInt, appMetaDataVersion: AppMetaDataVersionInt, fileUUID: String, failureExpected: Bool = false) -> String? {
        let exp = self.expectation(description: "exp")
        var result:String?
        
        ServerAPI.session.downloadAppMetaData(appMetaDataVersion: appMetaDataVersion, fileUUID: fileUUID, serverMasterVersion: masterVersion) { serverResult in
            switch serverResult {
            case .success(.appMetaData(let appMetaData)):
                if failureExpected {
                    XCTFail()
                }
                else {
                    result = appMetaData
                }
                
            case .success(.serverMasterVersionUpdate(_)):
                XCTFail()
                
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
    func uploadAndDownloadOneFileUsingStart() -> (ServerAPI.File, MasterVersionInt)? {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        let expectedFiles = [file]
        var downloadCount = 0
        
        shouldSaveDownload = { url, attr in
            downloadCount += 1
            XCTAssert(downloadCount == 1)
            XCTAssert(self.filesHaveSameContents(url1: file.localURL, url2: url as URL))
        }
        
        let expectation = self.expectation(description: "start")

        SyncManager.session.start { (error) in
            XCTAssert(error == nil)
            XCTAssert(downloadCount == 1)
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
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
    func uploadDeletion() -> (fileUUID:String, MasterVersionInt)? {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let (_, file) = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            return nil
        }
        
        // for the file upload
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)

        let fileToDelete = ServerAPI.FileToDelete(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        uploadDeletion(fileToDelete: fileToDelete, masterVersion: masterVersion+1)
        
        getUploads(expectedFiles: [
            (fileUUID: fileUUID, fileSize: nil)
        ]) { fileInfo in
            XCTAssert(fileInfo.deleted)
        }
        
        return (fileUUID, masterVersion+1)
    }
    
    func uploadDeletionOfOneFileWithDoneUploads() {
        guard let (fileUUID, masterVersion) = uploadDeletion() else {
            XCTFail()
            return
        }

        self.doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        self.getUploads(expectedFiles: []) { file in
            XCTAssert(file.fileUUID != fileUUID)
        }
        
        var foundDeletedFile = false
        
        getFileIndex(expectedFiles: [
            (fileUUID: fileUUID, fileSize: nil)
        ]) { file in
            if file.fileUUID == fileUUID {
                foundDeletedFile = true
                XCTAssert(file.deleted)
            }
        }
        
        XCTAssert(foundDeletedFile)
    }
    
    func uploadAndDownloadTextFile(appMetaData:AppMetaData? = nil, uploadFileURL:URL = Bundle(for: TestCase.self).url(forResource: "UploadMe", withExtension: "txt")!, fileUUID:String? = nil) {
    
        let masterVersion = getMasterVersion()
        
        var actualFileUUID:String! = fileUUID
        if fileUUID == nil {
            actualFileUUID = UUID().uuidString
        }
        
        guard let (fileSize, file) = uploadFile(fileURL:uploadFileURL, mimeType: .text, fileUUID: actualFileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        onlyDownloadFile(comparisonFileURL: uploadFileURL, file: file, masterVersion: masterVersion + 1, appMetaData: appMetaData, fileSize: fileSize)
    }
    
    func onlyDownloadFile(comparisonFileURL:URL, file:Filenaming, masterVersion:MasterVersionInt, appMetaData:AppMetaData? = nil, fileSize:Int64? = nil) {
        let expectation = self.expectation(description: "doneUploads")

        let fileNamingObj = FilenamingWithAppMetaDataVersion(fileUUID: file.fileUUID, fileVersion: file.fileVersion, appMetaDataVersion: appMetaData?.version)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj, serverMasterVersion: masterVersion) { (result, error) in
            
            guard let result = result, error == nil else {
                XCTFail()
                return
            }
            
            if case .success(let downloadedFile) = result {
                XCTAssert(FilesMisc.compareFiles(file1: comparisonFileURL, file2: downloadedFile.url as URL))
                if appMetaData != nil {
                    XCTAssert(downloadedFile.appMetaData == appMetaData)
                }
                if fileSize != nil {
                    XCTAssert(fileSize == downloadedFile.fileSizeBytes)
                }
            }
            else {
                XCTFail("\(result)")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func uploadSingleFileUsingSync(fileUUID:String = UUID().uuidString, fileURL:SMRelativeLocalURL? = nil, appMetaData:String? = nil, uploadCopy:Bool = false) -> (SMRelativeLocalURL, SyncAttributes)? {
        
        var url:SMRelativeLocalURL
        var originalURL:SMRelativeLocalURL
        
        if fileURL == nil {
            url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        }
        else {
            url = fileURL!
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

        var attr = SyncAttributes(fileUUID: fileUUID, mimeType: .text)
        if let appMetaData = appMetaData {
            attr.appMetaData = appMetaData
        }
        
        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted, .singleFileUploadComplete]
        let expectation1 = self.expectation(description: "test1")
        let expectation2 = self.expectation(description: "test2")
        let expectation3 = self.expectation(description: "test3")
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                expectation1.fulfill()
                
            case .fileUploadsCompleted(numberOfFiles: let number):
                XCTAssert(number == 1)
                expectation2.fulfill()
                
            case .singleFileUploadComplete(attr: let attr):
                XCTAssert(attr.fileUUID == fileUUID)
                XCTAssert(attr.mimeType == .text)
                expectation3.fulfill()
                
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
            try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
        return (originalURL, attr)
    }
    
    func resetFileMetaData(removeServerFiles:Bool=true, actualDeletion:Bool=true) {        
        do {
            try SyncServer.resetMetaData()
        } catch {
            XCTFail()
        }

        if removeServerFiles {
            removeAllServerFilesInFileIndex(actualDeletion:actualDeletion)
        }
    }
    
    func doASingleDownloadUsingSync(fileName: String, fileExtension:String, mimeType:MimeType, appMetaData:AppMetaData? = nil) {
        let initialDeviceUUID = self.deviceUUID

        // First upload a file.
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!

        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        let expectation = self.expectation(description: "test1")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        shouldSaveDownload = { url, attr in
            downloadCount += 1
            XCTAssert(downloadCount == 1)
            XCTAssert(attr.appMetaData == appMetaData?.contents)
            expectation.fulfill()
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
        
        XCTAssert(initialDeviceUUID != ServerAPI.session.delegate.deviceUUID(forServerAPI: ServerAPI.session))
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        // 9/16/17; I'm getting an odd test interaction. The test immediately after this one is failing seemingly because there is a download available *after* this test. This is to check to see if somehow there is a DownloadFileTracker still available. There shouldn't be.
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let dfts = DownloadFileTracker.fetchAll()
            XCTAssert(dfts.count == 0)
        }
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
}

extension TestCase : ServerAPIDelegate {    
    func doneUploadsRequestTestLockSync(forServerAPI: ServerAPI) -> TimeInterval? {
        testLockSyncCalled = true
        return testLockSync
    }
    
    func fileIndexRequestServerSleep(forServerAPI: ServerAPI) -> TimeInterval? {
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
    func syncServerAppMetaDataDownloadComplete(attr: SyncAttributes) {
        syncServerAppMetaDataDownloadComplete(attr)
    }
    
    func syncServerSingleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
        shouldSaveDownload(url, attr)
    }
    
    func syncServerShouldDoDeletions(downloadDeletions: [SyncAttributes]) {
        shouldDoDeletions(downloadDeletions)
    }
    
    func syncServerMustResolveContentDownloadConflict(downloadedFile: SMRelativeLocalURL?, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) {
        syncServerMustResolveContentDownloadConflict?(downloadedFile, downloadedContentAttributes, uploadConflict)
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

extension TestCase : SyncServerTestingDelegate {
    func syncServerSingleFileUploadCompleted(next: @escaping ()->()) {
        if syncServerSingleFileUploadCompleted == nil {
            next()
        }
        else {
            syncServerSingleFileUploadCompleted!(next)
        }
    }
    
    func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes, next: @escaping ()->()) {
        if syncServerSingleFileDownloadCompleted == nil {
            next()
        }
        else {
            syncServerSingleFileDownloadCompleted!(url, attr, next)
        }
     }
}
