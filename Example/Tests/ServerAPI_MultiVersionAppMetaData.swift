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
        
        let fileIndex = getFileIndex()
        
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
    }
    
    func testUploadInitialNonZeroVersionAppMetaDataFails() {
    }
    
    func testUploadAppMetaDataMultipleVersionWorks() {
        // Upload app meta version 0 -- with endpoint.
        // Then version 1 with endpoint.
    }
    
    func testDownloadAppMetaDataWithNilVersionFails() {
    }

    func testDownloadAppMetaDataWithVersion0Works() {
    }
    
    func testDownloadAppMetaDataWithVersion1Works() {
    }
}
