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

// Each of these tests run in two parts, and have to be run manually. Or at least the second part has to be started up manually after the first part crashes.
// These tests must have the flag BACKGROUND_TASKS_TESTS set.

/*
I added code that runs when `BACKGROUND_TASKS_TESTS` is set for the simulator to work around the followin gissue. When I run the second test, I get a path that looks like this for the running app:

/Users/chris/Library/Developer/CoreSimulator/Devices/F1714332-2FED-4F13-B6BD-B1209F6FA457/data/Containers/Data/Application/767A45D9-4B23-4058-A185-B58283E43909/Documents/

But the URL session result download was stored:
/Users/chris/Library/Developer/CoreSimulator/Devices/F1714332-2FED-4F13-B6BD-B1209F6FA457/data/Containers/Data/Application/48D2714F-DED1-4B4F-B7CF-C1A61A8657E6/Library/Caches/com.apple.nsurlsessiond/Downloads/biz.SpasticMuffin.SyncServer/CFNetworkDownload_0Hnm5C.tmp

Notice that the path/UUID after `Application` differs!

I'm not sure if I'm going to run into this if I run on an actual device.
*/

class BackgroundDownloadTest: TestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUploadAndStartDownloadThenCrash() {
        resetFileMetaData()
        
        let fileName = "Cat"
        let fileExtension = "jpg"
        let mimeType = "image/jpeg"
        
        // First upload a file.
        let masterVersion = getMasterVersion()
        
        let fileUUID = UUID().uuidString
        let fileURL = Bundle(for: ServerAPI_UploadFile.self).url(forResource: fileName, withExtension: fileExtension)!

        guard let (_, _) = uploadFile(fileURL:fileURL, mimeType: mimeType, fileUUID: fileUUID, serverMasterVersion: masterVersion, appMetaData: nil) else {
            return
        }
        
        doneUploads(masterVersion: masterVersion, expectedNumberUploads: 1)
        
        let expectation = self.expectation(description: "test1")
        self.deviceUUID = Foundation.UUID()
        
        var downloadCount = 0
        
        shouldSaveDownload = { url, attr in
            downloadCount += 1
            XCTAssert(downloadCount == 1)
            expectation.fulfill()
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
                    print("\(x!)")
                }

            default:
                XCTFail()
            }
        }
        
        // Next, initiate the download using .sync()
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 60.0, handler: nil)
    }
    
    // After the first test, wait a minute or two for the download to finish in the background. Then, the defining expectation with this test is that the NetworkCached object will be used.
    func testRestartDownload() {
        SyncServer.session.eventsDesired = [.syncDone]
        SyncServer.session.delegate = self
        
        let done = self.expectation(description: "done")
        let saveDownload = self.expectation(description: "saveDownload")
        
        shouldSaveDownload = { url, attr in
            saveDownload.fulfill()
        }
        
        syncServerErrorOccurred = { error in
            XCTFail()
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            default:
                XCTFail()
            }
        }
        
        // Re-initiate the download.
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCrashDuringUpload() {
        let url = SMRelativeLocalURL(withRelativePath: "Cat.jpg", toBaseURLType: .mainBundle)!
        
        let uploadFileUUID = UUID().uuidString
        let attr = SyncAttributes(fileUUID: uploadFileUUID, mimeType: "image/jpeg")
        
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
                    print("\(x!)")
                }
            
            default:
                XCTFail()
            }
        }
        
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    func testRestartUpload() {
        SyncServer.session.eventsDesired = [.syncDone, .fileUploadsCompleted]
        SyncServer.session.delegate = self

        let done = self.expectation(description: "done")
        let uploaded = self.expectation(description: "uploaded")
        
        syncServerErrorOccurred = {error in
            XCTFail()
        }
        
        syncServerEventOccurred = {event in
            switch event {
            case .syncDone:
                done.fulfill()
                
            case .fileUploadsCompleted:
                uploaded.fulfill()
            
            default:
                XCTFail()
            }
        }
        
        SyncServer.session.sync()
        
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
