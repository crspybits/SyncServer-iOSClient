//
//  Uploads.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

extension Upload {
    private class func createNewPendingSync() throws {
        Singleton.get().pendingSync = (UploadQueue.newObject() as! UploadQueue)
        try CoreData.sessionNamed(Constants.coreDataName).context.save()
    }
    
    class func pendingSync() throws -> UploadQueue {
        if Singleton.get().pendingSync == nil {
            try createNewPendingSync()
        }
        
        return Singleton.get().pendingSync!
    }
    
    // Must have uploads in `pendingSync`. This does a `saveContext`.
    // The pending queue must have uploads for the sharingGroupId (only).
    class func movePendingSyncToSynced(sharingGroupId: SharingGroupId) throws {
        guard let pendingQueue = Singleton.get().pendingSync else {
            assert(false)
            return
        }

        assert(pendingQueue.uploads!.count > 0)
        
        let filtered = pendingQueue.uploadFileTrackers.filter {$0.sharingGroupId == sharingGroupId}
        guard filtered.count == pendingQueue.uploadFileTrackers.count else {
            throw SyncServerError.sharingGroupIdInconsistent
        }
        
        let uploadQueues = synced()
        uploadQueues.addToQueuesOverride(pendingQueue)
        
        // This does a `saveContext`, so don't need to do that again.
        try createNewPendingSync()
    }
    
    class func synced() -> UploadQueues {
        return UploadQueues.get()
    }
    
    class func haveSyncQueue(forSharingGroupId sharingGroupId: SharingGroupId) -> Bool {
        if let queues = queues(forSharingGroupId: sharingGroupId),
            queues.count > 0 {
            return true
        }
        else {
            return false
        }
    }
    
    private class func queues(forSharingGroupId sharingGroupId: SharingGroupId) -> [UploadQueue]? {
        guard let queues = Array(synced().queues!) as? [UploadQueue] else {
            return nil
        }
        
        return queues.filter {
            $0.uploadFileTrackers.count > 0 && $0.uploadFileTrackers[0].sharingGroupId == sharingGroupId
        }
    }
    
    class func getHeadSyncQueue(forSharingGroupId sharingGroupId: SharingGroupId) -> UploadQueue? {
        guard let queues = queues(forSharingGroupId: sharingGroupId),
            queues.count > 0 else {
            return nil
        }
        
        return queues[0]
    }
    
    // There must be a head sync queue.
    class func removeHeadSyncQueue(sharingGroupId: SharingGroupId) {
        let head = getHeadSyncQueue(forSharingGroupId: sharingGroupId)
        assert(head != nil)
        CoreData.sessionNamed(Constants.coreDataName).remove(head!)
    }
}
