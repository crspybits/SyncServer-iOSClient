//
//  _Development_Upload_Gone.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 11/14/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

class _Development_Upload_Gone: TestCase {
    override func setUp() {
        TestCase.currTestAccount = .facebook
        super.setUp()
        
        let exp = self.expectation(description: "exp")
        TimedCallback.withDuration(3) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

    override func tearDown() {
        super.tearDown()
    }
    
    /*
        * Upload file
            1) fileRemovedOrRenamed-- doesn't apply.
            2) userRemoved -- doesn't apply.
            3) authTokenExpiredOrRevoked
    */
    
    /*
        1) authTokenExpiredOrRevoked
            a) Original user, upload v0 of file to sharing group A
            b) Invite a sharing user to sharing group A; can also be an owning user
            c) Revoke auth token for original user.
                https://myaccount.google.com/permissions
            d) Attempt to upload v1 of the file, by the sharing user.
    */
    // You should be signed in as the original owning user when using this.
     let authTokenExpiredOrRevokedFileUUID = SMPersistItemString(name:
            "authTokenExpiredOrRevokedFileUUID_Upload", initialStringValue:"",  persistType: .userDefaults)
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
    
    // Do this after revoking the access token for the original sharing user.
    // And, uncomment the facebook line in setUp above.
    func testAuthTokenExpiredOrRevoked_2() {
        let originalOwningUser: TestAccount = .google

        resetFileMetaData(removeServerFiles:false)
        
        guard updateSharingGroupsWithSync() else {
            XCTFail()
            return
        }
        
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: "UploadMe", withExtension: "txt")!
        guard let cloudStorageType = originalOwningUser.accountType.toCloudStorageType(),
            let checkSum = Hashing.hashOf(url: fileURL, for: cloudStorageType) else {
            XCTFail()
            return
        }
        
        _ = uploadFile(fileURL:fileURL, mimeType: .text, sharingGroupUUID: sharingGroupUUID, fileUUID: authTokenExpiredOrRevokedFileUUID.stringValue, serverMasterVersion: masterVersion, fileVersion: 1, useCheckSum: checkSum, expectUploadGone: .authTokenExpiredOrRevoked)
    }
}

