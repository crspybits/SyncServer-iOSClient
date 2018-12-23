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
import SyncServer_Shared

class CoreDataTests: TestCase {
    
    override func setUp() {
        super.setUp()
        setupTest(removeServerFiles: false, actualDeletion: false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLocalURLOnUploadFileTracker() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let obj = UploadFileTracker.newObject() as! UploadFileTracker
            obj.localURL = SMRelativeLocalURL(withRelativePath: "foobar", toBaseURLType: .documentsDirectory)
            XCTAssert(obj.localURL != nil)
        }
    }
    
    func testThatUploadFileTrackersWorks() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let uq = UploadQueue.newObject() as! UploadQueue
            XCTAssert(uq.uploadFileTrackers.count == 0)
        }
    }
    
    func testThatPendingSyncQueueIsInitiallyEmpty() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(try! Upload.pendingSync().uploads!.count == 0)
        }
    }
    
    func addObjectToPendingSync(sharingGroupUUID: String) {
        let uft = UploadFileTracker.newObject() as! UploadFileTracker
        uft.fileUUID = UUID().uuidString
        uft.sharingGroupUUID = sharingGroupUUID
        try! Upload.pendingSync().addToUploads(uft)
    }
    
    func testThatPendingSyncQueueCanAddObject() {
        guard let sharingGroup = getFirstSharingGroup()else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            self.addObjectToPendingSync(sharingGroupUUID: sharingGroupUUID)

            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            
            XCTAssert(try! Upload.pendingSync().uploads!.count == 1)
        }
    }
    
    func testThatSyncedInitiallyIsEmpty() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(Upload.synced().queues!.count == 0)
        }
    }
    
    func testMovePendingSyncToSynced() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            self.addObjectToPendingSync(sharingGroupUUID: sharingGroupUUID)
            try! Upload.movePendingSyncToSynced(sharingGroupUUID: sharingGroupUUID)
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            XCTAssert(Upload.synced().queues!.count == 1)
        }
    }
    
    func testThatGetHeadSyncQueueWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            self.addObjectToPendingSync(sharingGroupUUID: sharingGroupUUID)
            try! Upload.movePendingSyncToSynced(sharingGroupUUID: sharingGroupUUID)
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            guard let uploadQueue = Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(uploadQueue.uploads!.count == 1)
        }
    }
    
    func testThatRemoveHeadSyncQueueWorks() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            self.addObjectToPendingSync(sharingGroupUUID: sharingGroupUUID)
            try! Upload.movePendingSyncToSynced(sharingGroupUUID: sharingGroupUUID)
            Upload.removeHeadSyncQueue(sharingGroupUUID: sharingGroupUUID)
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch {
                XCTFail()
            }
            XCTAssert(Upload.synced().queues!.count == 0)
        }
    }
    
    func testThatTrackingResetWorks() {
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let _ = DownloadFileTracker.newObject()
        }
        
        do {
            try SyncServer.session.reset(type: .tracking)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        let sharingGroupUUIDs = sharingGroups.map {$0.sharingGroupUUID}
        assertThereIsNoTrackingMetaData(sharingGroupUUIDs: sharingGroupUUIDs)
    }
    
    func testThatPlainResetWorks() {
        guard let sharingGroups = getSharingGroups() else {
            XCTFail()
            return
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let _ = DirectoryEntry.newObject()
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        do {
            try SyncServer.session.reset(type: .all)
        } catch (let error) {
            XCTFail("\(error)")
        }
        
        let sharingGroupUUIDs = sharingGroups.map {$0.sharingGroupUUID}
        assertThereIsNoMetaData(sharingGroupUUIDs: sharingGroupUUIDs)
    }
    
    func testLogAllTracking() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        XCTAssert(Log.deleteLogFile())
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let uuid = UUID().uuidString
        let attr = SyncAttributes(fileUUID: uuid, sharingGroupUUID: sharingGroupUUID, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        
        let exp = expectation(description: "testLogAllTracking")
        
        SyncServer.session.logAllTracking() {
            // Read the file from disk and see if the trailing marker is present.
            var fileContents:String!
            
            do {
                fileContents = try String(contentsOfFile: Log.logFileURL!.path)
            } catch (let error) {
                XCTFail("\(error)")
                return
            }

            XCTAssert(fileContents.contains(SyncServer.trailingMarker), "\(String(describing: fileContents))")
            
            exp.fulfill()
        }

        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testThatResetWorksWithObjectsInMetaData() {
        guard let sharingGroups = getSharingGroups(), sharingGroups.count > 0 else {
            XCTFail()
            return
        }
        
        let sharingGroup = sharingGroups[0]
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            self.addObjectToPendingSync(sharingGroupUUID: sharingGroupUUID)
            try! Upload.movePendingSyncToSynced(sharingGroupUUID: sharingGroupUUID)
            
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
        
        let sharingGroupUUIDs = sharingGroups.map {$0.sharingGroupUUID}
        
        assertThereIsNoMetaData(sharingGroupUUIDs: sharingGroupUUIDs)
    }
    
    // NetworkCached tests
    
    func createNetworkCached(withVersion version: Int32 = 0, fileUUID:String, download: Bool) {
        let url = URL(string: "https://www.SpasticMuffin.biz")!
        let downloadURL = SMRelativeLocalURL(withRelativePath: "Download.txt", toBaseURLType: .documentsDirectory)!
        let httpVersion = "1.0"
        let headers = ["some": "header", "fields": "here"]
        let statusCode = 200
        let origResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headers)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
    
    func testAddDifferentSharingGroupIdsToSameDCGFails() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(DownloadContentGroup.fetchAll().count == 0)
            
            let dft1 = DownloadFileTracker.newObject() as! DownloadFileTracker
            let fileGroupUUID = UUID().uuidString
            dft1.sharingGroupUUID = sharingGroupUUID
            do {
                try DownloadContentGroup.addDownloadFileTracker(dft1, to: fileGroupUUID)
            }
            catch {
                XCTFail()
                return
            }
            
            let dft2 = DownloadFileTracker.newObject() as! DownloadFileTracker
            dft2.sharingGroupUUID = UUID().uuidString
            do {
                try DownloadContentGroup.addDownloadFileTracker(dft2, to: fileGroupUUID)
                XCTFail()
            }
            catch {
            }
        }
    }
    
    func testAddToNewFileGroup() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(DownloadContentGroup.fetchAll().count == 0)
            let dft = DownloadFileTracker.newObject() as! DownloadFileTracker
            let fileGroupUUID = UUID().uuidString
            dft.sharingGroupUUID = sharingGroupUUID
            
            do {
                try DownloadContentGroup.addDownloadFileTracker(dft, to: fileGroupUUID)
            }
            catch {
                XCTFail()
                return
            }
            let dcgs = DownloadContentGroup.fetchAll()
            guard dcgs.count == 1, let downloads = dcgs[0].downloads else {
                XCTFail()
                return
            }
            
            XCTAssert(dcgs[0].fileGroupUUID == fileGroupUUID)
            XCTAssert(downloads.count == 1)
            XCTAssert(dcgs[0].dfts.count == 1)
        }
    }
    
    func testAddToExistingFileGroup() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            XCTAssert(DownloadContentGroup.fetchAll().count == 0)
            let fileGroupUUID = UUID().uuidString
            let dft1 = DownloadFileTracker.newObject() as! DownloadFileTracker
            dft1.sharingGroupUUID = sharingGroupUUID
            do {
                try DownloadContentGroup.addDownloadFileTracker(dft1, to: fileGroupUUID)
            }
            catch {
                XCTFail()
                return
            }
            
            let dft2 = DownloadFileTracker.newObject() as! DownloadFileTracker
            dft2.sharingGroupUUID = sharingGroupUUID

            do {
                try DownloadContentGroup.addDownloadFileTracker(dft2, to: fileGroupUUID)
            }
            catch {
                XCTFail()
                return
            }
            
            let dcgs = DownloadContentGroup.fetchAll()
            
            
            guard dcgs.count == 1, let downloads = dcgs[0].downloads else {
                XCTFail()
                return
            }
            
            XCTAssert(downloads.count == 2)
            XCTAssert(dcgs[0].fileGroupUUID == fileGroupUUID)
        }
    }
    
    func testFileGroupFudgeCase() {
        guard let sharingGroup = getFirstSharingGroup() else {
            XCTFail()
            return
        }
        
        let sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dft = DownloadFileTracker.newObject() as! DownloadFileTracker
            dft.sharingGroupUUID = sharingGroupUUID
            
            do {
                try DownloadContentGroup.addDownloadFileTracker(dft, to: nil)
            }
            catch {
                XCTFail()
                return
            }
                        
            let dcgs = DownloadContentGroup.fetchAll()

            guard dcgs.count == 1, let downloads = dcgs[0].downloads else {
                XCTFail()
                return
            }
            
            XCTAssert(downloads.count == 1)
            XCTAssert(dcgs[0].fileGroupUUID == nil)
        }
    }
    
    func testCleanupUploads() {
        let sharingGroupUUID = UUID().uuidString
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let uft1 = UploadFileTracker.newObject() as! UploadFileTracker
            uft1.status = .uploaded
            uft1.sharingGroupUUID = sharingGroupUUID
            
            let uft2 = UploadFileTracker.newObject() as! UploadFileTracker
            uft2.status = .uploaded
            uft2.sharingGroupUUID = sharingGroupUUID
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        SyncManager.cleanupUploads(sharingGroupUUID: sharingGroupUUID)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let ufts = UploadFileTracker.fetchAll().filter {$0.status == .uploaded}
            XCTAssert(ufts.count == 0)
        }
    }
}
