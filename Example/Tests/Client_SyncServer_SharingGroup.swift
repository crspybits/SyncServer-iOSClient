//
//  Client_SyncServer_SharingGroup.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 7/22/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import Foundation
import SyncServer_Shared

class Client_SyncServer_SharingGroup: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func upload(uploadCopy: Bool, sharingGroupUUID: String, failureExpected: Bool = false) {
        let fileUUID = UUID().uuidString
        var url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        
        if uploadCopy {
            guard let copyOfFileURL = FilesMisc.newTempFileURL() else {
                XCTFail()
                return
            }
            
            try! FileManager.default.copyItem(at: url as URL, to: copyOfFileURL as URL)
            url = copyOfFileURL
        }

        let attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        
        do {
            if uploadCopy {
                try SyncServer.session.uploadCopy(localFile: url, withAttributes: attr)
            }
            else {
                try SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
            }
            if failureExpected {
                XCTFail()
            }
        } catch {
            if !failureExpected {
                XCTFail()
            }
        }
    }
    
    func testMultipleSharingGroupsUploadImmutableFileBeforeSyncFails() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        upload(uploadCopy: false, sharingGroupUUID: sharingGroupUUID)
        let badSharingGroupUUID = UUID().uuidString
        upload(uploadCopy: false, sharingGroupUUID: badSharingGroupUUID, failureExpected: true)
    }
    
    func testMultipleSharingGroupsUploadCopyFileBeforeSyncFails() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        upload(uploadCopy: true, sharingGroupUUID: sharingGroupUUID)
        let badSharingGroupUUID = UUID().uuidString
        upload(uploadCopy: true, sharingGroupUUID: badSharingGroupUUID, failureExpected: true)
    }

    func testMultipleSharingGroupsUploadAppMetaDataBeforeSyncFails() {
        guard let sharingGroup = getFirstSharingGroup(),
            let sharingGroupUUID = sharingGroup.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        upload(uploadCopy: true, sharingGroupUUID: sharingGroupUUID)
        let badSharingGroupUUID = UUID().uuidString
        upload(uploadCopy: true, sharingGroupUUID: badSharingGroupUUID, failureExpected: true)
    }
    
    
    func testRemoveSharingGroupWithAFileWorks() {
        let sharingGroupUUID = UUID().uuidString
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) else {
            XCTFail()
            return
        }
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let fileIndexResult1 = getFileIndex(sharingGroupUUID: sharingGroupUUID),
            let fileIndex1 = fileIndexResult1.fileIndex else {
            XCTFail()
            return
        }
        
        let filteredResult1 = fileIndex1.filter{$0.fileUUID == attr.fileUUID}
        guard filteredResult1.count == 1 else {
            XCTFail()
            return
        }
        
        if let _ = removeSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: fileIndexResult1.masterVersion!) {
            XCTFail()
            return
        }
        
        getFileIndex(sharingGroupUUID: sharingGroupUUID, errorExpected: true)
        
        guard let fileIndexResult2 = getFileIndex(sharingGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        let filteredResult = fileIndexResult2.sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID}
        XCTAssert(filteredResult.count == 0)
    }
}
