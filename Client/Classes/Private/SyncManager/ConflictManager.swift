//
//  ConflictManager.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/17/18.
//

import Foundation
import SyncServer_Shared
import SMCoreLib

class ConflictManager {
    // completion's are called when the client has resolved all conflicts if there are any. If there are no conflicts, the call to the completion is synchronous.
    
    static func handleAnyFileDownloadConflict(attr:SyncAttributes, url: SMRelativeLocalURL, delegate: SyncServerDelegate, completion:@escaping (SyncAttributes?)->()) {
    
        var resolver: SyncServerConflict?
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let pendingUploads = UploadFileTracker.fetchAll()
            
            // For this file download we could have (a) an upload deletion conflict, (b) file upload conflict(s), or (c) both an upload deletion conflict and file upload conflict(s).
            
            // Do we have a pending upload deletion that conflicts with the file download? In this case there could be at most a single upload deletion. It's an error for the client to try to queue up more than one deletion (with sync's between them).
            let conflictingUploadDeletions = pendingUploads.filter(
                {$0.deleteOnServer && $0.fileUUID == attr.fileUUID})

            // Do we have pending file upload(s) that conflict with the file download? In this case there could be more than one upload with the same uuid. For example, if the client does a file upload of uuid X, syncs, then another upload of X, and then sync.
            let conflictingFileUploads = pendingUploads.filter(
                {!$0.deleteOnServer && $0.fileUUID == attr.fileUUID})
            
            if conflictingUploadDeletions.count > 0 && conflictingFileUploads.count > 0 {
                // This arises when a file was queued for upload, synced, and then queued for deletion and synced.
                resolver = SyncServerConflict(conflictType: .bothFileUploadAndDeletion, resolutionCallback: { resolution in
                
                    switch resolution {
                    case .deleteConflictingClientOperations, .useNeitherClientNorDownload:
                        // Should really just be one of these.
                        removeManagedObjects(conflictingUploadDeletions)
                        
                        removeManagedObjects(conflictingFileUploads)
                        
                        if resolution == .deleteConflictingClientOperations {
                            completion(nil)
                        }
                        else {
                            fallthrough
                        }
                        
                    case .keepConflictingClientOperations:
                        // We're going to disregard the file download.
                        completion(attr)
                    }
                })
            }
            else if conflictingFileUploads.count > 0 {
                resolver = SyncServerConflict(conflictType: .fileUpload, resolutionCallback: { resolution in
                
                    switch resolution {
                    case .deleteConflictingClientOperations, .useNeitherClientNorDownload:
                        removeManagedObjects(conflictingFileUploads)
                        
                        if resolution == .deleteConflictingClientOperations {
                            completion(nil)
                        }
                        else {
                            fallthrough
                        }
                        
                    case .keepConflictingClientOperations:
                        // We're going to disregard the file download.
                        completion(attr)
                    }
                })
            }
            else if conflictingUploadDeletions.count > 0 {
                resolver = SyncServerConflict(conflictType: .uploadDeletion, resolutionCallback: { resolution in
                
                    switch resolution {
                    case .deleteConflictingClientOperations, .useNeitherClientNorDownload:
                        removeManagedObjects(conflictingUploadDeletions)
                        
                        if resolution == .deleteConflictingClientOperations {
                            completion(nil)
                        }
                        else {
                            fallthrough
                        }
                        
                    case .keepConflictingClientOperations:
                        // We're going to disregard the file download.
                        completion(attr)
                    }
                })
            }
        }
        
        if let resolver = resolver {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveDownloadConflict(downloadedFile: url, downloadedFileAttributes: attr, uploadConflict: resolver)
        }
        else {
            completion(nil)
        }
    }
    
    // In the completion, gives attr's for the files the client doesn't wish to have deleted by the given download deletions.
    static func handleAnyDownloadDeletionConflicts(downloadDeletionAttrs:[SyncAttributes], delegate: SyncServerDelegate, completion:@escaping (_ keepTheseOnes: [SyncAttributes])->()) {
    
        var remainingDownloadDeletionAttrs = downloadDeletionAttrs
        
        // If we have a pending upload deletion, no worries. Then we have a "conflict" between a download deletion, and an upload deletion. Someone just beat us to it. No need to keep on with our upload deletion.
        // Let's go ahead and remove the pending deletions, if any.
        
        var conflicts = [(downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict)]()
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let pendingUploadDeletions = UploadFileTracker.fetchAll().filter({$0.deleteOnServer})
            
            let pendingDeletionsToRemove = fileUUIDIntersection(pendingUploadDeletions, downloadDeletionAttrs)
            pendingDeletionsToRemove.forEach() { (uft, attr) in
                let fileUUID = uft.fileUUID
                CoreData.sessionNamed(Constants.coreDataName).remove(uft)
                let index = remainingDownloadDeletionAttrs.index(where: {$0.fileUUID == fileUUID})!
                remainingDownloadDeletionAttrs.remove(at: index)
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
            
            // Now, let's see if we have pending file uploads conflicting with any of these deletions. This is a prioritization issue. There is a pending download deletion. The client has a pending file upload. The client needs to make a judgement call: Should their upload take priority and upload undelete the file, or should the download deletion be accepted?
            
            let pendingFileUploads = UploadFileTracker.fetchAll().filter({!$0.deleteOnServer})
            let conflictingFileUploads = fileUUIDIntersection(pendingFileUploads, remainingDownloadDeletionAttrs)
            
            if conflictingFileUploads.count > 0 {
                var numberConflicts = conflictingFileUploads.count
                var deletionsToIgnore = [SyncAttributes]()
                
                conflictingFileUploads.forEach { (conflictUft, attr) in
                    let resolver = SyncServerConflict(conflictType: .fileUpload, resolutionCallback: { resolution in
                        switch resolution {
                        case .deleteConflictingClientOperations, .useNeitherClientNorDownload:
                            removeConflictingUpload(pendingFileUploads: pendingFileUploads, fileUUID: attr.fileUUID)
                            if resolution == .useNeitherClientNorDownload {
                                fallthrough
                            }
                            
                        case .keepConflictingClientOperations:
                            // We're going to disregard the download deletion.
                            deletionsToIgnore += [attr]

                            // But, we need to mark the uft as an upload undeletion.
                            markUftAsUploadUndeletion(pendingFileUploads: pendingFileUploads, fileUUID: attr.fileUUID)
                        }
                        
                        numberConflicts -= 1
                        
                        if numberConflicts == 0 {
                            completion(deletionsToIgnore)
                        }
                    })
                    
                    conflicts += [(attr, resolver)]
                }
            }
        }
        
        if conflicts.count > 0 {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveDeletionConflicts(conflicts: conflicts)
        }
        else {
            completion([])
        }
    }
    
    // Where this gets tricky is what we need is that only the very first uft for this fileUUID needs to be an upload undeletion. i.e., the uft that will get serviced the first.
    private static func markUftAsUploadUndeletion(pendingFileUploads: [UploadFileTracker], fileUUID: String) {
    
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            var toKeep = pendingFileUploads.filter({$0.fileUUID == fileUUID})
            toKeep.sort(by: { (uft1, uft2) -> Bool in
                return uft1.age < uft2.age
            })
            toKeep[0].uploadUndeletion = true
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    // What we need to do here is to remove any pending file upload's with this UUID.
    private static func removeConflictingUpload(pendingFileUploads: [UploadFileTracker], fileUUID:String) {
        // [1] Having deadlock issue here. Resolving it by documenting that delegate is *not* called on main thread for the two conflict delegate methods. Not the best solution.
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let toDelete = pendingFileUploads.filter({$0.fileUUID == fileUUID})
            toDelete.forEach { uft in
                CoreData.sessionNamed(Constants.coreDataName).remove(uft)
            }

            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    private static func removeManagedObjects(_ managedObjects:[NSManagedObject]) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            managedObjects.forEach { managedObject in
                CoreData.sessionNamed(Constants.coreDataName).remove(managedObject)
            }
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }

    // Returns the pairs: (firstElem, secondElem) where those have matching fileUUID's. Assumes the second of the arrays doesn't have duplicate fileUUID's.
    private static func fileUUIDIntersection<S, T>(_ first: [S], _ second: [T]) -> [(S, T)] where T: FileUUID, S: FileUUID {
        var result = [(S, T)]()

        for secondElem in second {
            let filtered = first.filter({$0.fileUUID == secondElem.fileUUID})
            if filtered.count >= 1 {
                result += [(filtered[0], secondElem)]
            }
        }
        
        return result
    }
}
