//
//  CoreDataTests.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/25/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

// These tests operate locally, with no server access.

import XCTest
@testable import SyncServer
import SMCoreLib

class CoreDataTests: TestCase {
    
    override func setUp() {
        super.setUp()
        resetFileMetaData(removeServerFiles: false, actualDeletion: false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLocalURLOnUploadFileTracker() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let obj = UploadFileTracker.newObject() as! UploadFileTracker
            obj.localURL = SMRelativeLocalURL(withRelativePath: "foobar", toBaseURLType: .documentsDirectory)
            XCTAssert(obj.localURL != nil)
        }
    }
    
    func testThatUploadFileTrackersWorks() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let uq = UploadQueue.newObject() as! UploadQueue
            XCTAssert(uq.uploadFileTrackers.count == 0)
        }
    }
    
    func testThatPendingSyncQueueIsInitiallyEmpty() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            XCTAssert(try! Upload.pendingSync().uploads!.count == 0)
        }
    }
    
    func addObjectToPendingSync() {
        let uft = UploadFileTracker.newObject() as! UploadFileTracker
        uft.fileUUID = UUID().uuidString
        try! Upload.pendingSync().addToUploadsOverride(uft)
    }
    
    func testThatPendingSyncQueueCanAddObject() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            self.addObjectToPendingSync()

            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            
            XCTAssert(try! Upload.pendingSync().uploads!.count == 1)
        }
    }
    
    func testThatSyncedInitiallyIsEmpty() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            XCTAssert(Upload.synced().queues!.count == 0)
        }
    }
    
    func testMovePendingSyncToSynced() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            self.addObjectToPendingSync()
            try! Upload.movePendingSyncToSynced()
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            XCTAssert(Upload.synced().queues!.count == 1)
        }
    }
    
    func testThatGetHeadSyncQueueWorks() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            self.addObjectToPendingSync()
            try! Upload.movePendingSyncToSynced()
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            guard let uploadQueue = Upload.getHeadSyncQueue() else {
                XCTFail()
                return
            }
            
            XCTAssert(uploadQueue.uploads!.count == 1)
        }
    }
    
    func testThatRemoveHeadSyncQueueWorks() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            self.addObjectToPendingSync()
            try! Upload.movePendingSyncToSynced()
            Upload.removeHeadSyncQueue()
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            XCTAssert(Upload.synced().queues!.count == 0)
        }
    }
    
    func testThatPlainResetWorks() {
        do {
            try SyncServer.session.reset()
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        assertThereIsNoMetaData()
    }
    
    func testThatResetWorksWithObjectsInMetaData() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            self.addObjectToPendingSync()
            try! Upload.movePendingSyncToSynced()
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
        }
        
        do {
            try SyncServer.session.reset()
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        assertThereIsNoMetaData()
    }
}
