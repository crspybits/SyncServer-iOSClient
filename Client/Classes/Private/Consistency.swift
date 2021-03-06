//
//  Consistency.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/14/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class Consistency {
    static func check(sharingGroupUUID: String, localFiles:[UUIDString], repair:Bool = false, callback:((Error?)->())?) {
        ServerAPI.session.index(sharingGroupUUID: sharingGroupUUID) { response in
            var indexResult:ServerAPI.IndexResult!
            switch response {
            case .success(let result):
                indexResult = result
            case .error(let error):
                callback?(error)
                return
            }
            
            guard let fileInfo = indexResult.fileIndex else {
                callback?(SyncServerError.generic("No file info in index result."))
                return
            }
            
            var messageResult = ""

            // Present in local meta data, but not present locally. (If the file was not present in local meta data and not present locally, a sync would have fixed this).
            var serverFilesNotPresentLocally = [UUIDString]()
            
            // Present in local meta data, but not deleted.
            // var deletedServerFilesButPresentLocally = [UUIDString]()

            // First, check server files.
            for file in fileInfo {
                // Check against local files.
                if file.deleted! {
                    if localFiles.contains(file.fileUUID) {
                        messageResult += "Deleted Server file: \(file.fileUUID!) *is* in local files\n"
                    }
                }
                else {
                    if !localFiles.contains(file.fileUUID!) {
                        serverFilesNotPresentLocally += [file.fileUUID!]
                        messageResult += "Server file: \(file.fileUUID!) not in local files \(localFiles)\n"
                    }
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // We should have *every* entry in the local DirectoryEntry meta data also. These issues should never happen: Our sync should prevent these.
                    let entry = DirectoryEntry.fetchObjectWithUUID(uuid: file.fileUUID)
                    if entry == nil {
                        messageResult += "Server file: \(file.fileUUID!) not in DirectoryEntry meta data\n"
                    }
                    else if entry!.deletedLocally != file.deleted {
                        messageResult += "Server file: \(file.fileUUID!) and DirectoryEntry meta data have inconsistent deletion status: \(file.deleted!) versus \(entry!.deletedLocally)\n"
                    }
                }
            }
            
            for localFile in localFiles {
                // All local files should be non-deleted on server
                let result = fileInfo.filter {$0.fileUUID == localFile}
                if result.count == 0 {
                    messageResult += "Local file: \(localFile) not on server\n"
                }
                else if result[0].deleted! {
                    messageResult += "Local file: \(localFile) deleted on server\n"
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // And those local files should *all* be in the local meta data.
                    let entry = DirectoryEntry.fetchObjectWithUUID(uuid: localFile)
                    if entry == nil {
                        messageResult += "Local file: \(localFile) not in DirectoryEntry meta data\n"
                    }
                    else if entry!.deletedLocally {
                        messageResult += "Local file: \(localFile) marked as deleted in DirectoryEntry meta data\n"
                    }
                }
            }

            var entries:[DirectoryEntry]!

            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                // All the local data should be on the server.
                entries = DirectoryEntry.fetchAll()
                if entries.count != fileInfo.count {
                    messageResult += "DirectoryEntry meta data different size than on server: \(entries.count) versus \(fileInfo.count)\n"
                }
            }

            if messageResult.count > 0 {
                messageResult = "\nConsistency check: Results through \(localFiles.count) local files, \(fileInfo.count) server files, and \(entries.count) DirectoryEntry meta data entries:\n\(messageResult)"
                Log.warning(messageResult)
            }
            else {
                messageResult = "Consistency check: OK!"
                Log.info(messageResult)
            }
            
            if repair {
                do {
                    try repairServerFilesNotPresentLocally(fileUUIDs: serverFilesNotPresentLocally, sharingGroupUUID: sharingGroupUUID) {
                        callback?(nil)
                    }
                } catch (let error) {
                    callback?(error)
                }
            }
            else {
                callback?(nil)
            }
        }
    }
    
    static func repairServerFilesNotPresentLocally(fileUUIDs:[UUIDString], sharingGroupUUID: String, completion:@escaping ()->()) throws {
        if fileUUIDs.count == 0 {
            completion()
        }
        
        var resultError: Error?
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // The simplest means to deal with this seems to be to remove the associated DirectoryEntry, and then sync again.
            for fileUUID in fileUUIDs {
                let entry = DirectoryEntry.fetchObjectWithUUID(uuid: fileUUID)
                CoreData.sessionNamed(Constants.coreDataName).remove(entry!)
            }
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                resultError = error
            }
        }
        
        guard resultError == nil else {
            throw resultError!
        }

        // A bit odd calling back up to the SyncServer, but sync will not call back down to us.s
        // TODO: *3* Should use delegation here or a callback. Cleaner.
        try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID) {
            completion()
        }
    }
}
