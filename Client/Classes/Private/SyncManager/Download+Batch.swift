//
//  Download+Batch.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/19/19.
//

import Foundation
import SMCoreLib

// TODO: Looks like we need delegate callbacks from ServerNetworking to this. This is needed to handle the case where the app is launched, background downloads are still happening, and we need to be informed about those downloads finishing.

extension Download {
    static let maximumCurrentBatchedDownloads = 10
    
    // To be called when the app comes back to the foreground, to process any downloads that were completed while the app was in the background.
    func processCompletedDownloads() {
    }
    
    // Start additional downloads up to the maximum number in a batch. May actually start exceed the max number in a batch, depending on the number of downloads available per dcg-- because all downloads for a single dcg are started at the same time. Assumes this is called *after* `processCompletedDownloads`-- otherwise the count of the number of currently downloading files will not be accurate.
    func startBatch() {
        var dftsToStart = [DownloadFileTracker]()
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // How many downloads are in progress currently? (Assumes that any dft's are for the currently in-progress sharing group).
            let dfts = DownloadFileTracker.fetchAll()
            let alreadyDownloading = dfts.filter {$0.status == .downloading}
            let numberAdditionalDownloadsPossible = Download.maximumCurrentBatchedDownloads - alreadyDownloading.count
            guard numberAdditionalDownloadsPossible > 0 else {
                Log.msg("Not starting more downloads: At maximum already.")
                return
            }
            
            // Are there additional downloads that can be started?
            let downloadable = dfts.filter {$0.operation.isContents && $0.status == .notStarted}
            guard downloadable.count > 0 else {
                Log.msg("No other downloadable dfts.")
                return
            }
            
            // We can start more downloads-- progress on a by-DownloadContentGroup basis. Will start all dfts in a DownloadContentGroup if we start any in that dcg, so this may have us start more than maximumCurrentBatchedDownloads.
            let dcgs = DownloadContentGroup.fetchAll()
            
            for dcg in dcgs {
                if dftsToStart.count >= numberAdditionalDownloadsPossible {
                    break
                }
                
                if dcg.status != .notStarted {
                    continue
                }
                
                // Are there additional dft downloads for this dcg that can be started? (The check for .notStarted is redundant-- we start/don't start downloads for a single dcg in an all or nothing manner).
                let downloadable = dcg.dfts.filter {$0.operation.isContents && $0.status == .notStarted}
                
                if downloadable.count > 0 {
                    dftsToStart += downloadable
                }
            }
        } // CoreDataSync.perform ends
        
        if dftsToStart.count > 0 {
            Log.msg("Starting \(dftsToStart.count) additional downloads ...")
        }
    }
}
