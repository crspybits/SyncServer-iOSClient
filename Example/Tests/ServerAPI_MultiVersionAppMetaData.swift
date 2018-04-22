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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMakeSureAppMetaDataVersionIsInFileIndex() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        guard let fileIndex = getFileIndex() else {
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
    }
    
    func testUploadInitialAppMetaDataWithEndpointWorks() {
        /* Steps:
        1) Upload file with nil app meta data.
        2) Done uploads
        3) Upload app meta data version 0
        4) Done uploads.
        5) File index to check app meta data version.
        */
        
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        guard let fileIndex = getFileIndex() else {
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
    }
    
    func testInitialNonZeroVersionAppMetaDataFails_UsingUploadFile() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData = AppMetaData(version: 1, contents: "Foobar")
        uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true, appMetaData:appMetaData)
    }
    
    func testInitialNonZeroVersionAppMetaDataFails_UsingUploadAppMetaData() {
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData = AppMetaData(version: 1, contents: "Foobar")
        uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, failureExpected: true)
    }
    
    func testUploadAppMetaDataMultipleVersionWorks() {
        // Upload app meta version 0 -- with endpoint.
        // Then version 1 with endpoint.
        
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData1, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData2 = AppMetaData(version: 1, contents: "Foobar2")
        guard uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData2, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        guard let fileIndex = getFileIndex() else {
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
    }
    
    func testDownloadAppMetaDataWithNilVersionFails() {
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, failureExpected: true)
    }

    func testDownloadAppMetaDataWithVersion0Works() {
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaData.contents == appMetaDataContents)
    }
    
    func testDownloadAppMetaDataWithVersion1Works() {
        var masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        let appMetaData1 = AppMetaData(version: 0, contents: "Foobar")
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData1) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        let appMetaData2 = AppMetaData(version: 1, contents: "Foobar2")
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData:appMetaData2, fileVersion: 1) else {
            XCTFail()
            return
        }
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        masterVersion += 1
        
        guard let appMetaDataContents = downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 1, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(appMetaData2.contents == appMetaDataContents)
        
        guard let fileIndex = getFileIndex() else {
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
    }
    
    func testAppMetaDataUploadWithBadMasterVersionFails() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        
        guard let _ = uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion) else {
            XCTFail()
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        // Don't increment the master version
        
        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        uploadAppMetaData(masterVersion: masterVersion, appMetaData: appMetaData, fileUUID: fileUUID, failureExpected: true)
    }
    
    func testAppMetaDataDownloadWithBadMasterVersionFails() {
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!

        let appMetaData = AppMetaData(version: 0, contents: "Foobar")
        uploadFile(fileURL:fileURL, mimeType: .text, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: appMetaData)
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        // Don't increment the master version
        
        downloadAppMetaData(masterVersion: masterVersion, appMetaDataVersion: 0, fileUUID: fileUUID, failureExpected: true)
    }
}