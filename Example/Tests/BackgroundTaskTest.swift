//
//  UploadCrashTest.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 1/6/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

// For ideas about how to extend the current background task operation, see https://github.com/crspybits/SharedImages/issues/36

// Each of these tests run in two parts, and have to be run manually. Or at least the second part has to be started up manually after the first part crashes.
// These tests must have the flag BACKGROUND_TASKS_TESTS set.

/*
I added code that runs when `BACKGROUND_TASKS_TESTS` is set for the simulator to work around the following issue. When I run the second test, I get a path that looks like this for the running app:

/Users/chris/Library/Developer/CoreSimulator/Devices/F1714332-2FED-4F13-B6BD-B1209F6FA457/data/Containers/Data/Application/767A45D9-4B23-4058-A185-B58283E43909/Documents/

But the URL session result download was stored:
/Users/chris/Library/Developer/CoreSimulator/Devices/F1714332-2FED-4F13-B6BD-B1209F6FA457/data/Containers/Data/Application/48D2714F-DED1-4B4F-B7CF-C1A61A8657E6/Library/Caches/com.apple.nsurlsessiond/Downloads/biz.SpasticMuffin.SyncServer/CFNetworkDownload_0Hnm5C.tmp

Notice that the path/UUID after `Application` differs!

I'm not sure if I'm going to run into this if I run on an actual device.
*/

class BackgroundTaskTest: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /* Testing procedure, on the simulator (so I can access files):
        1) Run this test; it will crash. Let the download complete from the server without resetting Xcode.
        2) Stop the app in Xcode.
        3) Using the path given in the top of the console log, e.g.,
            /Users/chris/Library/Developer/CoreSimulator/Devices/1583F915-F527-4166-B898-B3F83C5AA889/data/Containers/Data/Application/635B24D5-0C74-440C-AD98-552CE245CB42/Documents
            Open a terminal window and look at debugging.txt
            Look for "Using cached download result"
    */
    func testUploadAndStartDownloadThenCrash() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let fileName = "Cat"
        let fileExtension = "jpg"
        let mimeType:MimeType = .jpeg
        
        // First upload a file.
        guard let masterVersion = getLocalMasterVersionFor(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!

        guard let _ = uploadFile(fileURL:fileURL, mimeType: mimeType, sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: nil) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, expectedNumberUploads: 1)
        
        let expectation = self.expectation(description: "test1")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        syncServerFileGroupDownloadComplete = { group in
            if group.count == 1, case .file = group[0].type {
                downloadCount += 1
                XCTAssert(downloadCount == 1)
                expectation.fulfill()
            }
            else {
                XCTFail()
            }
        }
        
        SyncServer.session.eventsDesired = [.syncDone, .willStartDownloads]
        SyncServer.session.delegate = self

        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                // We're going to force a crash before this.
                XCTFail()
                
            case .willStartDownloads:
                // We need to give the download a moment to actually start. At this exact point in the code, it hasn't actually yet started.
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    let x:Int! = nil
                    SyncServer.backgroundTest.boolValue = true
                    print("\(x!)")
                }

            default:
                XCTFail()
            }
        }
        
        // Next, initiate the download using .sync()
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 60.0, handler: nil)
    }

    // Same procedure as above, but output: "Using cached upload result"
    func testCrashDuringUpload() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        let url = SMRelativeLocalURL(withRelativePath: "Cat.jpg", toBaseURLType: .mainBundle)!
        
        let uploadFileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: uploadFileUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .jpeg)
        
        SyncServer.session.eventsDesired = [.syncDone, .willStartUploads]
        SyncServer.session.delegate = self

        let expectation1 = self.expectation(description: "test1")
        
        syncServerErrorOccurred = {error in
            XCTFail()
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                XCTFail()
                expectation1.fulfill()
                
            case .willStartUploads:
                // We need to give the upload a moment to actually start. At this exact point in the code, it hasn't actually yet started.
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    let x:Int! = nil
                    SyncServer.backgroundTest.boolValue = true
                    print("\(x!)")
                }
            
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        try! SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
