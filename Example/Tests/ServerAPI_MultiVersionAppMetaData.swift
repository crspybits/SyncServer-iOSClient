//
//  ServerAPI_MultiVersionAppMetaData.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 4/4/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class ServerAPI_MultiVersionAppMetaData: TestCase {
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMakeSureAppMetaDataVersionIsInFileIndex() {
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
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredFileIndex = fileIndex.filter { fileInfo in
            fileInfo.fileUUID == fileUUID
        }
        
        guard filteredFileIndex.count == 1,
            filteredFileIndex[0].appMetaDataVersion == appMetaData.version else {
            XCTFail()
            return
        }
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadInitialAppMetaDataWithEndpointWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        /* Steps:
        1) Upload file with nil app meta data.
        2) Done uploads
        3) Upload app meta data version 0
        4) Done uploads.
        5) File index to check app meta data version.
        */
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredFileIndex = fileIndex.filter { fileInfo in
            fileInfo.fileUUID == fileUUID
        }
        
        guard filteredFileIndex.count == 1,
            filteredFileIndex[0].appMetaDataVersion == appMetaData.version else {
            XCTFail()
            return
        }
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testInitialNonZeroVersionAppMetaDataFails_UsingUploadFile() {
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
        
        let appMetaData = AppMetaData(version: 1, contents: "Foobar")
        uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true, appMetaData:appMetaData)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testInitialNonZeroVersionAppMetaDataFails_UsingUploadAppMetaData() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData = AppMetaData(version: 1, contents: "Foobar")
        uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, failureExpected: true)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testUploadAppMetaDataMultipleVersionWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        // Upload app meta version 0 -- with endpoint.
        // Then version 1 with endpoint.
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData1, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData2 = AppMetaData(version: 1, contents: "Foobar2")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData2, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredFileIndex = fileIndex.filter { fileInfo in
            fileInfo.fileUUID == fileUUID
        }
        
        guard filteredFileIndex.count == 1,
            filteredFileIndex[0].appMetaDataVersion == appMetaData2.version else {
            XCTFail()
            return
        }

        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDownloadAppMetaDataWithNilVersionFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, failureExpected: true)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }

    func testDownloadAppMetaDataWithVersion0Works() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaData.contents == appMetaDataContents)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testDownloadAppMetaDataWithVersion1Works() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard var masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData1) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData2 = AppMetaData(version: 1, contents: "Foobar2")
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData2, fileVersion: 1) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        masterVersion += 1
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 1, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaData2.contents == appMetaDataContents)
        
        guard let fileIndexResult = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex = fileIndexResult.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredFileIndex = fileIndex.filter { fileInfo in
            fileInfo.fileUUID == fileUUID
        }
        
        guard filteredFileIndex.count == 1,
            filteredFileIndex[0].appMetaDataVersion == appMetaData2.version else {
            XCTFail()
            return
        }
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testAppMetaDataUploadWithBadMasterVersionFails() {
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
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        // Don't increment the master version
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, failureExpected: true)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    func testAppMetaDataDownloadWithBadMasterVersionFails() {
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

        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData)
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        // Don't increment the master version
        
        downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, failureExpected: true)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
    
    // Cannot upload v0 of a file using appMetaData upload.
    func testUploadV0OfFileUsingAppMetaDataUploadFails() {
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
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, failureExpected: true)
        
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: SyncServer.session.sharingGroups.map {$0.sharingGroupUUID})
    }
}
