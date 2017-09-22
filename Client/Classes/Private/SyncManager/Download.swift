//
//  Download.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class Download {
    var desiredEvents:EventDesired!
    weak var delegate:SyncServerDelegate?
    
    static let session = Download()
    
    private init() {
    }
    
    enum OnlyCheckCompletion {
    case checkResult(downloadFiles:[FileInfo]?, downloadDeletions:[FileInfo]?, MasterVersionInt?)
    case error(Error)
    }
    
    // TODO: *0* while this check is occurring, we want to make sure we don't have a concurrent check operation.
    // Doesn't create DownloadFileTracker's or update MasterVersion.
    func onlyCheck(completion:((OnlyCheckCompletion)->())? = nil) {
        
        Log.msg("Download.onlyCheckForDownloads")
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            guard error == nil else {
                completion?(.error(error!))
                return
            }

            var completionResult:OnlyCheckCompletion!
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                do {
                    let (downloads, deletions) =
                        try Directory.session.checkFileIndex(fileIndex: fileIndex!)
                    completionResult =
                        .checkResult(downloadFiles:downloads, downloadDeletions:deletions, masterVersion)
                } catch (let error) {
                    completionResult = .error(error)
                }
                
                completion?(completionResult)
            }
        }
    }
    
    enum CheckCompletion {
    case noDownloadsOrDeletionsAvailable
    case downloadsAvailable(numberOfDownloadFiles:Int32, numberOfDownloadDeletions:Int32)
    case error(Error)
    }
    
    // TODO: *0* while this check is occurring, we want to make sure we don't have a concurrent check operation.
    // Creates DownloadFileTracker's to represent files that need downloading/download deleting. Updates MasterVersion with the master version on the server.
    func check(completion:((CheckCompletion)->())? = nil) {
        onlyCheck() { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                completion?(.error(error))
            
            case .checkResult(downloadFiles: let fileDownloads, downloadDeletions: let downloadDeletions, let masterVersion):
                
                var completionResult:CheckCompletion!

                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    Singleton.get().masterVersion = masterVersion!
                    
                    if fileDownloads == nil && downloadDeletions == nil {
                        completionResult = .noDownloadsOrDeletionsAvailable
                    }
                    else {
                        let allFiles = (fileDownloads ?? []) + (downloadDeletions ?? [])
                        var numberFileDownloads:Int32 = 0
                        var numberDownloadDeletions:Int32 = 0
                        
                        for file in allFiles {
                            if file.fileVersion != 0 {
                                // TODO: *5* We're considering this an error currently because we're not yet supporting multiple file versions.
                                assert(false, "Not Yet Implemented: Multiple File Versions")
                            }
                            
                            let dft = DownloadFileTracker.newObject() as! DownloadFileTracker
                            dft.fileUUID = file.fileUUID
                            dft.fileVersion = file.fileVersion
                            dft.mimeType = file.mimeType
                            dft.deletedOnServer = file.deleted!
                            
                            if file.deleted! {
                                numberDownloadDeletions += 1
                            }
                            else {
                                numberFileDownloads += 1
                            }
                            
                            if file.creationDate != nil {
                                dft.creationDate = file.creationDate! as NSDate
                                dft.updateDate = file.updateDate! as NSDate
                            }
                        }
                        
                        completionResult = .downloadsAvailable(numberOfDownloadFiles:numberFileDownloads, numberOfDownloadDeletions:numberDownloadDeletions)
                    }
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error(error)
                        return
                    }
                } // End performAndWait
                
                completion?(completionResult)
            }
        }
    }

    enum NextResult {
    case started
    case noDownloadsOrDeletions
    case allDownloadsCompleted
    case error(String)
    }
    
    enum NextCompletion {
    case fileDownloaded(url:SMRelativeLocalURL, attr:SyncAttributes, dft: DownloadFileTracker)
    case masterVersionUpdate
    case error(String)
    }
    
    // Starts download of next file, if there is one. There should be no files downloading already. Only if .started is the NextResult will the completion handler be called. With a masterVersionUpdate response for NextCompletion, the MasterVersion Core Data object is updated by this method, and all the DownloadFileTracker objects have been reset.
    func next(first: Bool = false, completion:((NextCompletion)->())?) -> NextResult {
        var masterVersion:MasterVersionInt!
        var nextResult:NextResult?
        var downloadFile:FilenamingObject!
        var nextToDownload:DownloadFileTracker!
        var numberToDownload = 0
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            guard dfts.count != 0 else {
                nextResult = .noDownloadsOrDeletions
                return
            }
            
            numberToDownload = dfts.count

            let alreadyDownloading = dfts.filter {$0.status == .downloading}
            guard alreadyDownloading.count == 0 else {
                let message = "Already downloading a file!"
                Log.error(message)
                nextResult = .error(message)
                return
            }
            
            let notStarted = dfts.filter {$0.status == .notStarted && !$0.deletedOnServer}
            guard notStarted.count != 0 else {
                nextResult = .allDownloadsCompleted
                return
            }
            
            masterVersion = Singleton.get().masterVersion

            nextToDownload = notStarted[0]
            nextToDownload.status = .downloading
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error("\(error)")
            }
            
            // Need this inside the `performAndWait` to bridge the gap without an NSManagedObject
            downloadFile = FilenamingObject(fileUUID: nextToDownload.fileUUID, fileVersion: nextToDownload.fileVersion)
        }
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        if first {
            EventDesired.reportEvent( .willStartDownloads(numberDownloads: UInt(numberToDownload)), mask: desiredEvents, delegate: delegate)
        }
        
        ServerAPI.session.downloadFile(file: downloadFile, serverMasterVersion: masterVersion) { (result, error)  in
        
            // Don't hold the performAndWait while we do completion-- easy to get a deadlock!

            guard error == nil else {
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToDownload.status = .notStarted
                    
                    // Not going to check for exceptions on saveContext; we already have an error.
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                
                let message = "Error: \(String(describing: error))"
                Log.error(message)
                completion?(.error(message))
                return
            }
            
            switch result! {
            case .success(let downloadedFile):
                var nextCompletionResult:NextCompletion!
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // 9/16/17; Not really crucial since we'll be deleting this DownloadFileTracker quickly. But, useful for testing.
                    nextToDownload.status = .downloaded
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                    
                    // TODO: Not using downloadedFile.fileSizeBytes. Why?
                    
                    var attr = SyncAttributes(fileUUID: nextToDownload.fileUUID, mimeType: nextToDownload.mimeType!, creationDate: nextToDownload.creationDate! as Date, updateDate: nextToDownload.updateDate! as Date)
                    attr.appMetaData = downloadedFile.appMetaData
                    attr.creationDate = nextToDownload.creationDate as Date?
                    attr.updateDate = nextToDownload.updateDate as Date?
                    
                    // Not removing nextToDownload yet because I haven't called the client completion callback yet-- will do the deletion after that.
                    
                    nextCompletionResult = .fileDownloaded(url:downloadedFile.url, attr:attr, dft: nextToDownload)
                }
        
                completion?(nextCompletionResult)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                // 9/18/17; We're doing downloads in an eventually consistent manner. See http://www.spasticmuffin.biz/blog/2017/09/15/making-downloads-more-flexible-in-the-syncserver/
                // The following will remove any outstanding DownloadFileTrackers. If we've already downloaded a file-- those dft's will have been removed already. This is part of our eventually consistent operation. It is possible that some of the already downloaded files may need to be deleted (or updated, when we get to multiple file versions).
                
                var nextCompletionResult:NextCompletion!
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    DownloadFileTracker.removeAll()
                    Singleton.get().masterVersion = masterVersionUpdate
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        nextCompletionResult = .error("\(error)")
                        return
                    }
                    
                    nextCompletionResult = .masterVersionUpdate
                }
                
                completion?(nextCompletionResult)
            }
        }
        
        return .started
    }
}
