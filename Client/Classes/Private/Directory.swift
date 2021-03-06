//
//  Directory.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

// Meta info for files known to the client.

class Directory {
    static var session = Directory()
    weak var delegate:SyncServerDelegate!
    
    private init() {
    }
    
    struct DownloadSet {
        let downloadFiles:Set<FileInfo>
        let downloadDeletions:Set<FileInfo>
        let downloadAppMetaData:Set<FileInfo>
        
        func isEmpty() -> Bool {
            return downloadFiles.count == 0 && downloadDeletions.count == 0 && downloadAppMetaData.count == 0
        }
        
        func allFiles() -> Set<FileInfo> {
            return downloadFiles.union(downloadDeletions).union(downloadAppMetaData)
        }
    }
    
    /* Compares the passed fileIndex to the current DirecotoryEntry objects, and returns just the FileInfo objects we need to download/delete, if any. Except for the following, the directory is not changed as a result of this call:
        a) the case where the file isn't in the directory already, but has been deleted on the server. 5/19/18;
        b) a case of migration to using file groups
        c) a case of migration to having a cloudStorageType attribute
        d) a bug with mime types.
     
        Does not do `CoreDataSync.perform(sessionName: Constants.coreDataName)`
        1/25/18; Now dealing with the case where a file is marked as deleted locally, but was undeleted on the server-- we need to download the file again.
        3/23/18; Now dealing with appMetaData versioning.
    */
    func checkFileIndex(serverFileIndex:[FileInfo]) throws -> DownloadSet {
    
        var downloadFiles = Set<FileInfo>()
        var downloadDeletions = Set<FileInfo>()
        var downloadAppMetaData = Set<FileInfo>()

        enum Action {
        case needToDownloadFile
        case needToDownloadAppMetaData
        case needToDownloadAndUndelete
        case needToDelete
        case none
        }
        
        for serverFile in serverFileIndex {
            var action:Action = .none

            if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: serverFile.fileUUID) {
                // Have the file in client directory.
                
                if let _ = entry.gone {
                    continue
                }
                
                // Going to also check for forced downloads here because (a) if we don't have the file on the server, we can't download it, and (b) we need the FileInfo from the server to do the download. Plus, server requests (e.g., to delete the file) take priority over app requests -- the server is our source of truth.

                if entry.deletedOnServer {
                    /* If we have the file marked as deleted:
                        a) File (still) deleted on the server: Don't need to do anything.
                        b) File not deleted on the server: We need to download.
                    */
                
                    if !serverFile.deleted {
                        // We think it's deleted; server thinks it's not deleted. The file must have been undeleted.
                        action = .needToDownloadAndUndelete
                    }
                }
                else {
                    if serverFile.deleted! {
                        action = .needToDelete
                    }
                    else if entry.fileVersion != serverFile.fileVersion {
                        // Not same file version here locally as on server
                        action = .needToDownloadFile
                    }
                    else if entry.appMetaDataVersion != serverFile.appMetaDataVersion {
                        // Not the same appMetaData version locally as on server.
                        action = .needToDownloadAppMetaData
                    }
                    else if entry.forceDownload {
                        action = .needToDownloadFile
                    }
                }
                
                // 5/19/18; This is really more of a migration, but it seem simplest to put it here. This is needed to change to using file groups.
                if entry.fileGroupUUID == nil && serverFile.fileGroupUUID != nil {
                    entry.fileGroupUUID = serverFile.fileGroupUUID
                }
                
                // 5/19/18; Dealing with a bug that came up today.
                if entry.mimeType == nil && serverFile.mimeType != nil {
                    entry.mimeType = serverFile.mimeType
                }
                
                // 10/30/18; Again, this is more of a migration. If we already know about the file, we ought to know about its cloudStorageType. i.e., if we uploaded v0 of the file, we will know it's cloud storage type, or if it was unknown before we would have obtained its cloud storage type-- when we downloaded the file.
                if entry.cloudStorageType == nil {
                    guard let serverCloudStorageType = serverFile.cloudStorageType else {
                        throw SyncServerError.generic("Server didn't have cloud storage type for fileUUID: \(String(describing: serverFile.fileGroupUUID))")
                    }
                    
                    entry.cloudStorageType = CloudStorageType(rawValue: serverCloudStorageType)
                }
            }
            else { // File is unknown to the client.
                // Will never do just an appMetaData download in this case because an initial download of a file will also download any appMetaData for the file.
                
                if serverFile.deleted! {
                    // The file is unknown to the client, plus it's deleted on the server. No need to inform the client, but for consistency I'm going to create an entry in the directory.
                    let entry = DirectoryEntry.newObject() as! DirectoryEntry
                    entry.deletedLocally = true
                    entry.fileUUID = serverFile.fileUUID
                    entry.fileVersion = serverFile.fileVersion
                    entry.sharingGroupUUID = serverFile.sharingGroupUUID
                    
                    if let serverCloudStorageType = serverFile.cloudStorageType {
                        entry.cloudStorageType = CloudStorageType(rawValue: serverCloudStorageType)
                    }
                    
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                }
                else {
                    action = .needToDownloadFile
                }
            }
            
            // For these actions, we need to create or modify DirectoryEntry, but do this later. Not going to do these changes right now because then this state looks identical to having downloaded/deleted the file/version previously.
            
            switch action {
            case .needToDownloadFile, .needToDownloadAndUndelete:
                downloadFiles.insert(serverFile)
                
            case .needToDelete:
                downloadDeletions.insert(serverFile)
                
            case .needToDownloadAppMetaData:
                downloadAppMetaData.insert(serverFile)
                
            case .none:
                break
            }
        } // End iterating over server files.

        let downloadSet = DownloadSet(
                downloadFiles: downloadFiles,
                downloadDeletions: downloadDeletions,
                downloadAppMetaData: downloadAppMetaData)
        return downloadSet
    }
    
    // Does not do `CoreDataSync.perform(sessionName: Constants.coreDataName)`
    // This for file and appMetaData downloads (not download deletions).
    func updateAfterDownloading(downloads:[DownloadFileTracker]) {
        for dft in downloads {
            if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: dft.fileUUID) {
                // So we don't repeatedly try to download the same file.
                if let goneReason = dft.gone {
                    entry.gone = goneReason
                    continue
                }
                
                // This will really only ever happen in testing: A situation where the DirectoryEntry has been created for the file uuid, but we don't have a fileVersion assigned. e.g., The file gets uploaded (not using the sync system), then uploaded by the sync system, and then we get the download that was created not using the sync system.
#if !DEBUG
                if entry.fileVersion! >= dft.fileVersion {
                    Thread.runSync(onMainThread: {[unowned self] in
                        self.delegate.syncServerErrorOccurred(error:
                            .downloadedFileVersionNotGreaterThanCurrent)
                    })
                }
#endif

                if dft.operation == .file {
                    entry.fileVersion = dft.fileVersion
                    
                    // 1/25/18; Deal with undeletion. The logic is: We did a download of a file that was already deleted. This must mean undeletion.
                    if entry.deletedLocally {
                        entry.deletedLocally = false
                    }
                    
                    // Don't update the fileGroupUUID-- this never changes after v0 of the file.
                }
                
                // For appMetaData downloads, does the dft have a mimeType??
                if entry.mimeType != dft.mimeType {
                    Log.error("entry.mimeType: \(String(describing: entry.mimeType)); dft.mimeType: \(String(describing: dft.mimeType)); entry.fileUUID: \(String(describing: entry.fileUUID))")
                    Thread.runSync(onMainThread: {[unowned self] in
                        self.delegate.syncServerErrorOccurred(error: .mimeTypeOfFileChanged)
                    })
                }
                
                // Only assign the appMetaData if it's non-nil-- otherwise, the value isn't intended to be changed by the previously uploading client.
                if let appMetaData = dft.appMetaData {
                    entry.appMetaData = appMetaData
                    entry.appMetaDataVersion = dft.appMetaDataVersion
                }
            }
            else {
                let newEntry = DirectoryEntry.newObject() as! DirectoryEntry
                newEntry.fileUUID = dft.fileUUID
                newEntry.mimeType = dft.mimeType
                newEntry.fileGroupUUID = dft.fileGroupUUID
                newEntry.sharingGroupUUID = dft.sharingGroupUUID
                newEntry.cloudStorageType = dft.cloudStorageType
                
                if let goneReason = dft.gone {
                    newEntry.gone = goneReason
                    continue
                }
                
                newEntry.fileVersion = dft.fileVersion
                newEntry.appMetaData = dft.appMetaData
                newEntry.appMetaDataVersion = dft.appMetaDataVersion
            }
        }
    }
    
    // Does not do `CoreDataSync.perform(sessionName: Constants.coreDataName)`
    func updateAfterDownloadDeletingFiles(deletions:[SyncAttributes], pendingUploadUndeletions: [SyncAttributes]) {
        deletions.forEach { attr in
            // Have already dealt with case where we didn't know about this file locally and were download deleting it.
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                assert(false)
                return
            }
            
            entry.deletedLocally = true
        }
        
        // This is a special case-- a conflict between a download deletion (server has file deleted) and an upload undeletion. So that FileIndex server calls don't attempt to do further download deletions, we need to have the file marked as deleted on the server-- but not deletedLocally.
        pendingUploadUndeletions.forEach { attr in
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                assert(false)
                return
            }

            entry.deletedOnServer = true
        }
    }
}
