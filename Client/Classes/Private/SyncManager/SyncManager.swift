//
//  SyncManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/26/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class SyncManager {
    static let session = SyncManager()
    weak var delegate:SyncServerDelegate!
    private var _stopSync = false
    
    // The getter returns the current value and sets it to false. Operates in an atomic manner.
    var stopSync: Bool {
        set {
            Synchronized.block(self) {
                _stopSync = newValue
            }
        }
        
        get {
            var result: Bool = false
            
            Synchronized.block(self) {
                result = _stopSync
                _stopSync = false
            }
            
            return result
        }
    }

    private var callback:((SyncServerError?)->())?
    var desiredEvents:EventDesired = .defaults

    private init() {
    }
    
    enum StartError : Error {
    case error(String)
    }
    
    private func needToStop() -> Bool {
        if stopSync {
            EventDesired.reportEvent(.syncStopping, mask: self.desiredEvents, delegate: self.delegate)
            callback?(nil)
            return true
        }
        else {
            return false
        }
    }
    
    // TODO: *1* If we get an app restart when we call this method, and an upload was previously in progress, and we now have download(s) available, we need to reset those uploads prior to doing the downloads.
    func start(sharingGroupUUID: String, first: Bool = false, _ callback:((SyncServerError?)->())? = nil) {
        self.callback = callback
        
        // TODO: *1* This is probably the level at which we should ensure that multiple download operations are not taking place concurrently. E.g., some locking mechanism?
        
        if self.needToStop() {
            return
        }
        
        // First: Do we have previously queued downloads that need to be done?
        let nextResult = Download.session.next(first: first) {[weak self] nextCompletionResult in
            switch nextCompletionResult {
            case .fileDownloaded(let dft):
                var dcg: DownloadContentGroup!
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    dcg = dft.group!
                }
                self?.downloadCompleted(dcg: dcg, callback:callback)
                
            case .appMetaDataDownloaded(dft: let dft):
                var dcg: DownloadContentGroup!
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    dcg = dft.group!
                }
                self?.downloadCompleted(dcg: dcg, callback:callback)

            case .masterVersionUpdate:
                // Need to start all over again.
                self?.start(sharingGroupUUID: sharingGroupUUID, callback)
                
            case .error(let error):
                callback?(error)
            }
        }
        
        switch nextResult {
        case .currentGroupCompleted(let dcg):
            downloadCompleted(dcg: dcg, callback:callback)
            
        case .noDownloadsOrDeletions:
            checkForDownloads(sharingGroupUUID: sharingGroupUUID)
            
        case .error(let error):
            callback?(SyncServerError.otherError(error))
            
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            return
            
        case .allDownloadsCompleted:
            resetSharingEntry(forSharingGroupUUID: sharingGroupUUID)
            checkForPendingUploads(sharingGroupUUID: sharingGroupUUID, first: true)
        }
    }
    
    private func resetSharingEntry(forSharingGroupUUID sharingGroupUUID: String) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            if let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) {
                sharingEntry.syncNeeded = false
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
            }
            else {
                Log.error("Could not find SharingEntry with sharingGroupUUID:  \(sharingGroupUUID)")
            }
        }
    }
    
    func sharingGroupDoesNotExistSync(sharingGroupUUID: String, _ callback:((SyncServerError?)->())? = nil) {
        self.callback = callback
        checkForPendingUploads(sharingGroupUUID: sharingGroupUUID, first: true)
    }
    
    private func downloadCompleted(dcg: DownloadContentGroup, callback:((SyncServerError?)->())? = nil) {
        var allCompleted:Bool!
        var sharingGroupUUID:String!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            sharingGroupUUID = dcg.sharingGroupUUID
            allCompleted = dcg.allDftsCompleted()
            if allCompleted {
                dcg.status = .downloaded
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
            }
        }
        
        if allCompleted {
            // All downloads completed for this group. Wrap it up.
            completeGroup(sharingGroupUUID: sharingGroupUUID, dcg: dcg)
        }
        else {
            // Downloads are not completed for this group. Recursively check for any next downloads (i.e., other groups). Using `async` so we don't consume extra space on the stack.
            DispatchQueue.global().async {
                self.start(sharingGroupUUID: sharingGroupUUID, callback)
            }
        }
    }
    
    private func completeGroup(sharingGroupUUID: String, dcg:DownloadContentGroup) {
        var contentDownloads:[DownloadFileTracker]!
        var downloadDeletions:[DownloadFileTracker]!
        
        Log.msg("Completed DownloadContentGroup: Checking for conflicts")
        
        // Deal with any content download conflicts and any download deletion conflicts.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            contentDownloads = dcg.dfts.filter {$0.operation.isContents}
            downloadDeletions = dcg.dfts.filter {$0.operation.isDeletion}
        }
        
        // 12/27/18; Up until today, I was updating the DirectoryEntry's (see Directory class) within handleAnyContentDownloadConflicts and handleAnyDownloadDeletionConflicts (before the client was informed of changes) but this led to an error condition-- https://github.com/crspybits/SyncServer-iOSClient/issues/63 where, seemingly, the directory could get updated (i.e., file versions updated), and the client not informed of changes. Instead, I'm going to first inform the client of changes, and then update the directory. So, in the worst case if work is repeated due to a failure, a client would be informed of changes multiple times.
        
        ConflictManager.handleAnyContentDownloadConflicts(dfts: contentDownloads, delegate: self.delegate) { downloadsToIgnore in
            
            ConflictManager.handleAnyDownloadDeletionConflicts(dfts: downloadDeletions, delegate: self.delegate) { deleteAllOfThese, updateDirectoryAfterDownloadDeletingFiles in

                var groupContent:[DownloadOperation]!
                var numberGone = 0
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    let updatedContentDownloads = contentDownloads.filter { dft in
                        let shouldIgnore = downloadsToIgnore.filter {$0.fileUUID == dft.fileUUID}
                        return shouldIgnore.count == 0
                    }
                    
                    let updatedDownloadDeletions = downloadDeletions.filter { dft in
                        let shouldIgnore = deleteAllOfThese.filter {$0.fileUUID == dft.fileUUID}
                        return shouldIgnore.count == 0
                    }
                    
                    let dfts = updatedContentDownloads + updatedDownloadDeletions
                    
                    groupContent = dfts.map { dft in
                        var contentType:DownloadOperation.OperationType!
                        switch dft.operation! {
                        case .file:
                            if let _ = dft.gone  {
                                contentType = .fileGone
                                numberGone += 1
                            }
                            else {
                                contentType = .file(dft.localURL!, contentsChanged: dft.contentsChangedOnServer)
                            }
                        case .appMetaData:
                            contentType = .appMetaData
                        case .deletion:
                            contentType = .deletion
                        case .sharingGroup:
                            // We're not dealing with sharing group downloads in this manner.
                            assert(false)
                        }
                        
                        return DownloadOperation(type: contentType, attr: dft.attr)
                    }
                } // CoreDataSync.perform ends
                
                if groupContent.count > 0 {
                    if numberGone > 0 {
                        Thread.runSync(onMainThread: {
                            self.delegate!.syncServerFileGroupDownloadGone(group: groupContent)
                        })
                    }
                    else {
                        Thread.runSync(onMainThread: {
                            self.delegate!.syncServerFileGroupDownloadComplete(group: groupContent)
                        })
                    }
                }
                
                // 12/27/18; Updating the directory *after* informimg the client. If an error occurs, in the worst case we should end up just informing the client more than once.
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    Directory.session.updateAfterDownloading(downloads: contentDownloads)
                    updateDirectoryAfterDownloadDeletingFiles?()
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {                    
                    // Remove the DownloadContentGroup and related dft's -- We're finished their downloading.
                    dcg.dfts.forEach { dft in
                        dft.remove()
                    }
                    dcg.remove()
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                
                // Downloads are completed for this file group, but we may have other file groups to download.
                DispatchQueue.global().async {
                    self.start(sharingGroupUUID: sharingGroupUUID, self.callback)
                }
            } // ConflictManager.handleAnyDownloadDeletionConflicts ends
        } // ConflictManager.handleAnyContentDownloadConflicts ends
    }

    // No DownloadFileTracker's queued up. Check the FileIndex to see if there are pending downloads on the server.
    private func checkForDownloads(sharingGroupUUID: String) {
        if self.needToStop() {
            return
        }
        
        Download.session.check(sharingGroupUUID: sharingGroupUUID) { checkCompletion in
            switch checkCompletion {
            case .noDownloadsOrDeletionsAvailable:
                self.resetSharingEntry(forSharingGroupUUID: sharingGroupUUID)
                self.checkForPendingUploads(sharingGroupUUID: sharingGroupUUID, first: true)
                
            case .downloadsAvailable(numberOfContentDownloads:let numberContentDownloads, numberOfDownloadDeletions:let numberDownloadDeletions):
                // This is not redundant with the `willStartDownloads` reporting in `Download.session.next` because we're calling start with first=false (implicitly), so willStartDownloads will not get reported twice.
                EventDesired.reportEvent(
                    .willStartDownloads(numberContentDownloads: UInt(numberContentDownloads), numberDownloadDeletions: UInt(numberDownloadDeletions)),
                    mask: self.desiredEvents, delegate: self.delegate)
                
                // We've got DownloadFileTracker's queued up now. Go deal with them!
                self.start(sharingGroupUUID: sharingGroupUUID, self.callback)
                
            case .error(let error):
                self.callback?(error)
            }
        }
    }
    
    private func checkForPendingUploads(sharingGroupUUID: String, first: Bool = false) {
        if self.needToStop() {
            return
        }
        
        func getSharingGroup(sharingGroupUUID: String, removedFromGroupOK: Bool = false) -> SyncServer.SharingGroup? {
            var sharingEntry:SharingEntry!
            var sharingGroup: SyncServer.SharingGroup!
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID)
                Log.msg("getSharingGroup: \(String(describing: sharingEntry)); \(removedFromGroupOK)")
                
                if !removedFromGroupOK {
                    guard !sharingEntry.removedFromGroup else {
                        sharingEntry = nil
                        return
                    }
                }
                
                sharingGroup = sharingEntry.toSharingGroup()
            }

            if sharingEntry == nil {
                callback?(.generic("Could not get sharing entry."))
                return nil
            }
            
            return sharingGroup
        }
        
        let nextResult = Upload.session.next(sharingGroupUUID: sharingGroupUUID, first: first) {[unowned self] nextCompletion in
            switch nextCompletion {
            case .fileUploaded(let attr, let uft):
                self.contentWasUploaded(attr: attr, uft: uft)

            case .appMetaDataUploaded(uft: let uft):
                self.contentWasUploaded(attr: nil, uft: uft)
                
            case .uploadDeletion(let fileUUID):
                EventDesired.reportEvent(.singleUploadDeletionComplete(fileUUID: fileUUID), mask: self.desiredEvents, delegate: self.delegate)
                // Recursively see if there is a next upload to do.
                self.checkForPendingUploads(sharingGroupUUID: sharingGroupUUID)
                
            case .sharingGroupCreated:
                guard let sharingGroup = getSharingGroup(sharingGroupUUID: sharingGroupUUID) else {
                    return
                }
                EventDesired.reportEvent(
                    .sharingGroupUploadOperationCompleted(sharingGroup: sharingGroup, operation: .creation), mask: self.desiredEvents, delegate: self.delegate)
                self.checkForPendingUploads(sharingGroupUUID: sharingGroupUUID)
            
            // This is the success response to the endpoint call, RemoveUserFromSharingGroup
            case .userRemovedFromSharingGroup:
                guard let sharingGroup = getSharingGroup(sharingGroupUUID: sharingGroupUUID, removedFromGroupOK: true) else {
                    return
                }
                
                EventDesired.reportEvent(
                    .sharingGroupUploadOperationCompleted(sharingGroup: sharingGroup, operation: .userRemoval), mask: self.desiredEvents, delegate: self.delegate)
                // No need to check for pending uploads-- this will have been the only operation in the queue. And don't do done uploads-- that will fail because we're no longer in the sharing group (and wouldn't do anything even if we were).
                SyncManager.cleanupUploads(sharingGroupUUID: sharingGroupUUID)
                self.callback?(nil)
                
            case .masterVersionUpdate:
                // Things have changed on the server. Check for downloads again. Don't go all the way back to `start` because we know that we don't have queued downloads.
                self.checkForDownloads(sharingGroupUUID: sharingGroupUUID)
                
            case .error(let error):
                self.callback?(error)
            }
        }
        
        switch nextResult {
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            break
            
        case .noOperation:
           self.checkForPendingUploads(sharingGroupUUID: sharingGroupUUID)
            
        case .noUploads:
            SyncManager.cleanupUploads(sharingGroupUUID: sharingGroupUUID)
            callback?(nil)
            
        case .allUploadsCompleted:
            self.doneUploads(sharingGroupUUID: sharingGroupUUID)
            
        case .error(let error):
            callback?(error)
        }
    }
    
    private func contentWasUploaded(attr:SyncAttributes?, uft: UploadFileTracker) {
        var operation: FileTracker.Operation!
        var fileUUID:String!
        var sharingGroupUUID: String!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            operation = uft.operation
            fileUUID = uft.fileUUID
            sharingGroupUUID = uft.sharingGroupUUID
        }
        
        switch operation! {
        case .file:
            if attr!.gone == nil {
                EventDesired.reportEvent(.singleFileUploadComplete(attr: attr!), mask: self.desiredEvents, delegate: self.delegate)
            }
            else {
                EventDesired.reportEvent(.singleFileUploadGone(attr: attr!), mask: self.desiredEvents, delegate: self.delegate)
            }
            
        case .appMetaData:
            EventDesired.reportEvent(.singleAppMetaDataUploadComplete(fileUUID: fileUUID), mask: self.desiredEvents, delegate: self.delegate)
        case .deletion:
            assert(false)
            
        case .sharingGroup:
            // Event reported with the specific operation.
            break
        }
        
        // Recursively see if there is a next upload to do.
        DispatchQueue.global().async {
            self.checkForPendingUploads(sharingGroupUUID: sharingGroupUUID)
        }
    }
    
    private func doneUploads(sharingGroupUUID: String) {
        Upload.session.doneUploads(sharingGroupUUID: sharingGroupUUID) { completionResult in
            switch completionResult {
            case .masterVersionUpdate:
                self.checkForDownloads(sharingGroupUUID: sharingGroupUUID)
                
            case .error(let error):
                self.callback?(error)
                
            // `numTransferred` may not be accurate in the case of retries/recovery.
            case .doneUploads(numberTransferred: _):
                var uploadQueue:UploadQueue!
                var contentUploads:[UploadFileTracker]!
                var uploadDeletions:[UploadFileTracker]!
                var errorResult:SyncServerError?

                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // 4/18/18; Got a crash here during testing because `Upload.getHeadSyncQueue()` returned nil. How is that possible? An earlier test failed-- wonder if it could have "leaked" into a later test?
                    uploadQueue = Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID)
                    if uploadQueue == nil {
                        errorResult = .generic("Nil result from getHeadSyncQueue.")
                        return
                    }
                    
                    contentUploads = uploadQueue.uploadTrackers.filter {$0.operation.isContents} as? [UploadFileTracker]
                }
                
                if errorResult != nil {
                    self.callback?(errorResult)
                    return
                }
                
                if contentUploads.count > 0 {
                    EventDesired.reportEvent(.contentUploadsCompleted(numberOfFiles: contentUploads.count), mask: self.desiredEvents, delegate: self.delegate)
                }
    
                CoreDataSync.perform(sessionName: Constants.coreDataName) { [unowned self] in
                    if contentUploads.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be given its version, as uploaded. And appMetaData needs to be updated in directory if it has been updated on this upload.
                        contentUploads.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            // 1/27/18; [1]. It's safe to update the local directory entry version(s) -- we've done the upload *and* we've done the DoneUploads too.
                            
                            // Only update the directory entry if the file wasn't gone on the server.
                            if uft.gone == nil {
                                // Only if we're updating a file do we need to update our local directory file version. appMetaData uploads don't deal with file versions.
                                if uft.operation! == .file {
                                    uploadedEntry.fileVersion = uft.fileVersion
                                }
                                
                                // We may need to update the appMetaData and version for either a file upload (which can also update the appMetaData) or (definitely) for an appMetaData upload.
                                 if let _ = uft.appMetaData {
                                    uploadedEntry.appMetaData = uft.appMetaData
                                    uploadedEntry.appMetaDataVersion = uft.appMetaDataVersion
                                }
                                
                                // Deal with special case where we had marked directory entry as `deletedOnServer`.
                                if uft.uploadUndeletion && uploadedEntry.deletedOnServer {
                                    uploadedEntry.deletedOnServer = false
                                }
                            }
                            
                            do {
                                try uft.remove()
                            } catch {
                                self.delegate?.syncServerErrorOccurred(error:
                                    .couldNotRemoveFileTracker)
                            }
                        }
                    }
                    
                    uploadDeletions = uploadQueue.uploadTrackers.filter {$0.operation.isDeletion} as? [UploadFileTracker]
                } // end perform

                if uploadDeletions.count > 0 {
                    EventDesired.reportEvent(.uploadDeletionsCompleted(numberOfFiles: uploadDeletions.count), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    if uploadDeletions.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be marked as deleted.
                        uploadDeletions.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            uploadedEntry.deletedLocally = true
                            do {
                                try uft.remove()
                            } catch {
                                errorResult = .couldNotRemoveFileTracker
                            }
                        }
                    }
                    
                    CoreData.sessionNamed(Constants.coreDataName).remove(uploadQueue)
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        errorResult = .coreDataError(error)
                        return
                    }
                } // end perform
                
                SyncManager.cleanupUploads(sharingGroupUUID: sharingGroupUUID)
                
                self.callback?(errorResult)
            }
        }
    }

    // 4/22/18; I ran into the need for this during a crash Dany was having. For some reason there were 10 uft's on his app that were marked as uploaded. But for some reason had never been deleted. I'm calling this from places where there should not be uft's in this state-- so they should be removed. This is along the lines of garbage collection. Not sure why it's needed...
    // Not marking this as `private` so I can add a test case.
    static func cleanupUploads(sharingGroupUUID: String) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {        
            let uploadedUfts = UploadFileTracker.fetchAll().filter
                { $0.status == .uploaded && $0.sharingGroupUUID == sharingGroupUUID}
            uploadedUfts.forEach { uft in
                do {
                    try uft.remove()
                } catch (let error) {
                    Log.error("Error removing uft: \(error)")
                }
            }
            
            let uploadedSguts = SharingGroupUploadTracker.fetchAll().filter
                { $0.status == .uploaded && $0.sharingGroupUUID == sharingGroupUUID}
            uploadedSguts.forEach { sgut in
                sgut.remove()
            }
            
            let emptyQueues = UploadQueue.fetchAll().filter {$0.uploadTrackers.count == 0}
            emptyQueues.forEach { emptyQueue in
                emptyQueue.remove()
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}

