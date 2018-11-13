//
//  _Development_Download_Gone.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 11/11/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class _Development_Download_Gone: TestCase {
    override func setUp() {
        // TestCase.currTestAccount = .facebook
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    /*
        1) fileRemovedOrRenamed:
            a) Upload a file and do Done Uploads. Need to retain the fileUUID.
                Can use the sync upload method.
            b) Manually remove the file from, say, Google Drive.
            c) Attempt to download the file. Can use the download endpoint.
    */
    let fileRemovedOrRenamedFileUUID = SMPersistItemString(name:
            "fileRemovedOrRenamedFileUUID", initialStringValue:"",  persistType: .userDefaults)
    func testFileRemovedOrRenamed_1() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroup.sharingGroupUUID) else {
            XCTFail()
            return
        }

        fileRemovedOrRenamedFileUUID.stringValue = attr.fileUUID
    }
    
    func testFileRemovedOrRenamed_DownloadAPI_2() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroup.sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "doneUploads")

        let fileNamingObj = FilenamingWithAppMetaDataVersion(fileUUID: fileRemovedOrRenamedFileUUID.stringValue, fileVersion: 0, appMetaDataVersion: nil)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroup.sharingGroupUUID) { (result, error) in
            
            if let result = result {
                switch result {
                case .success:
                    XCTFail()
                case .gone(let goneReason):
                    XCTAssert(goneReason == .fileRemovedOrRenamed)
                case .serverMasterVersionUpdate:
                    XCTFail()
                }
            }
            else {
                XCTFail("error: \(String(describing: error))")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /*
        2) userRemoved
            a) Original user, upload a file to sharing group A
            b) Invite a sharing user to sharing group A; can also be an owning user
            c  Remove original user from sharing group A
            d) Attempt to download the file, by the sharing user.
     
        NOTE: This download should actually be expected to fail. This is because as a part of removing the original user from the sharing group, the file will have been removed-- it will now be marked as removed in the FileIndex. The downloading client (sharing user) will first get the FileIndex, and that will result in a local deletion of the file. Thus, no download will be attempted.
    */
    // let userRemovedFileUUID = SMPersistItemString(name:
    //        "userRemovedFileUUID", initialStringValue:"",  persistType: .userDefaults)
    
    /*
        3) authTokenExpiredOrRevoked
            a) Original user, upload a file to sharing group A
            b) Invite a sharing user to sharing group A; can also be an owning user
            c  Revoke auth token for original user.
            d) Attempt to download the file, by the sharing user.
    */
    // You should be signed in as the original owning user when using this.
     let authTokenExpiredOrRevokedFileUUID = SMPersistItemString(name:
            "authTokenExpiredOrRevokedFileUUID", initialStringValue:"",  persistType: .userDefaults)
    func testAuthTokenExpiredOrRevoked_1() {
        resetFileMetaData()
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        guard let (_, attr) = uploadSingleFileUsingSync(sharingGroupUUID: sharingGroup.sharingGroupUUID) else {
            XCTFail()
            return
        }

        authTokenExpiredOrRevokedFileUUID.stringValue = attr.fileUUID
    }
    
    // To test this, first uncomment the facebook line in setUp, above.
    // Prior to using this, the sharing user should have been invited to the sharing group.
    func testAuthTokenExpiredOrRevoked_DownloadAPI_2() {
        resetFileMetaData()
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroup.sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let expectation = self.expectation(description: "doneUploads")

        let fileNamingObj = FilenamingWithAppMetaDataVersion(fileUUID: fileRemovedOrRenamedFileUUID.stringValue, fileVersion: 0, appMetaDataVersion: nil)

        ServerAPI.session.downloadFile(fileNamingObject: fileNamingObj, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroup.sharingGroupUUID) { (result, error) in
            
            if let result = result {
                switch result {
                case .success:
                    XCTFail()
                case .gone(let goneReason):
                    XCTAssert(goneReason == .authTokenExpiredOrRevoked)
                case .serverMasterVersionUpdate:
                    XCTFail()
                }
            }
            else {
                XCTFail("error: \(String(describing: error))")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
