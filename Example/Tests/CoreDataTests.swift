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
    
    func testThatTrackingResetWorks() {
        do {
            try SyncServer.session.reset(type: .tracking)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        assertThereIsNoTrackingMetaData()
    }
    
    func testThatPlainResetWorks() {
        do {
            try SyncServer.session.reset(type: .all)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        assertThereIsNoMetaData()
    }
    
    func testLogAllTracking() {
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let uuid = UUID().uuidString
        let attr = SyncAttributes(fileUUID: uuid, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        SyncServer.session.logAllTracking()
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
            try SyncServer.session.reset(type: .all)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        assertThereIsNoMetaData()
    }
    
    // NetworkCached tests
    
    func createNetworkCached(withVersion version: Int32 = 0, fileUUID:String, download: Bool) {
        let url = URL(string: "https://www.SpasticMuffin.biz")!
        let downloadURL = SMRelativeLocalURL(withRelativePath: "Download.txt", toBaseURLType: .documentsDirectory)!
        let httpVersion = "1.0"
        let headers = ["some": "header", "fields": "here"]
        let statusCode = 200
        let origResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headers)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let obj = NetworkCached.newObject() as! NetworkCached
            obj.fileUUID = fileUUID
            obj.fileVersion = version
            obj.httpResponse = origResponse
            if download {
                obj.downloadURL = downloadURL
            }
            obj.save()
            
            guard let fetchedObject = NetworkCached.fetchObjectWithUUID(fileUUID, andVersion: version, download: download) else {
                XCTFail()
                return
            }
            
            if download {
                XCTAssert(fetchedObject.downloadURL == downloadURL)
            }
            
            XCTAssert(fetchedObject.fileUUID == fileUUID)
            XCTAssert(fetchedObject.fileVersion == version)
            
            XCTAssert(fetchedObject.httpResponse?.statusCode == statusCode)
            
            for (origKey, origValue) in headers {
                guard let newValue = fetchedObject.httpResponse?.allHeaderFields[origKey] as? String, origValue == newValue else {
                    XCTFail()
                    return
                }
            }
            
            XCTAssert(fetchedObject.httpResponse?.url == url)
        }
    }
    
    func testCreateNetworkCachedUploadWithVersionOf0() {
        let fileUUID = UUID().uuidString
        createNetworkCached(withVersion: 0, fileUUID:fileUUID, download: false)
    }
    
    func testCreateNetworkCachedUploadWithVersionOf43() {
        let fileUUID = UUID().uuidString
        createNetworkCached(withVersion: 43, fileUUID:fileUUID, download: false)
    }
    
    func testCreateNetworkCachedDownload() {
        let fileUUID = UUID().uuidString
        createNetworkCached(withVersion: 0, fileUUID:fileUUID, download: true)
    }
    
    func testCreateBothUploadAndDownload() {
        let version:Int32 = 0
        
        let fileUUIDDownload = UUID().uuidString
        createNetworkCached(withVersion: version, fileUUID:fileUUIDDownload, download: true)
        
        let fileUUIDUpload = UUID().uuidString
        createNetworkCached(withVersion: version, fileUUID:fileUUIDUpload, download: false)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            guard let _ = NetworkCached.fetchObjectWithUUID(fileUUIDDownload, andVersion: version, download: true) else {
                XCTFail()
                return
            }
            
            guard let _ = NetworkCached.fetchObjectWithUUID(fileUUIDUpload, andVersion: version, download: false) else {
                XCTFail()
                return
            }
        }
    }
    
    func testFetchObjectWithServerURLKey() {
        let serverURL = URL(fileURLWithPath: "https://syncserver.cprince.com/FileIndex/")
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let obj = NetworkCached.newObject() as! NetworkCached
            obj.serverURLKey = serverURL.absoluteString
            obj.save()
            
            guard let fetchedObject = NetworkCached.fetchObjectWithServerURLKey(serverURL.absoluteString) else {
                XCTFail()
                return
            }
            
            XCTAssert(fetchedObject.serverURLKey == serverURL.absoluteString)
        }
    }
    
    func testDeletionOfStaleCacheEntriesDoesNothingWhenEntriesRecent() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let obj1 = NetworkCached.newObject() as! NetworkCached
            obj1.save()
            
            let obj2 = NetworkCached.newObject() as! NetworkCached
            obj2.save()
            
            NetworkCached.deleteOldCacheEntries()
            
            let all = NetworkCached.fetchAll()
            XCTAssert(all.count == 2)
        }
    }
    
    func testDeletionOfStaleCacheEntriesRemovesWhenEntriesOld() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let staleDate = NSCalendar.current.date(byAdding: .day, value: -(NetworkCached.staleNumberOfDays + 1), to: Date())!
            
            let obj1 = NetworkCached.newObject() as! NetworkCached
            obj1.dateTimeCached = staleDate as NSDate
            obj1.save()
            
            let obj2 = NetworkCached.newObject() as! NetworkCached
            obj2.dateTimeCached = staleDate as NSDate
            obj2.save()
            
            NetworkCached.deleteOldCacheEntries()
            
            let all = NetworkCached.fetchAll()
            XCTAssert(all.count == 0)
        }
    }
}
