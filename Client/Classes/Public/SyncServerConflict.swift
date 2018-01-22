//
//  SyncServerConflict.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/11/18.
//

import Foundation

// When you receive a conflict in a callback method, you must resolve the conflict by calling resolveConflict.
public class SyncServerConflict {
    typealias callbackType = ((ResolutionType)->())!
    
    var conflictResolved:Bool = false
    var resolutionCallback:((ResolutionType)->())!
    
    init(conflictType: ClientOperation, resolutionCallback:callbackType) {
        self.conflictType = conflictType
        self.resolutionCallback = resolutionCallback
    }
    
    // Because downloads are higher-priority (than uploads) with the SyncServer, all conflicts effectively originate from a server download operation: A download-deletion or a file-download. The type of server operation will be apparent from the context.
    // And the conflict is between the server operation and a local, client operation:
    public enum ClientOperation : String {
        case uploadDeletion
        case fileUpload
        case bothFileUploadAndDeletion
    }
    
    public private(set) var conflictType:ClientOperation!
    
    public enum ResolutionType {
        // E.g., suppose a download-deletion and a file-upload (ClientOperation.FileUpload) are conflicting.
        // Example continued: The client chooses to delete its conflicting file-upload and accept the download-deletion by using this resolution.
        case deleteConflictingClientOperations
        
        // In this example: The client chooses to make a new upload, for example, based on its own data and the download-- but use neither its prior upload or the download.
        case useNeitherClientNorDownload
        
        // Example continued: The client chooses to keep its conflicting file-upload, and override the download-deletion, by using this resolution.
        case keepConflictingClientOperations
    }
    
    public func resolveConflict(resolution:ResolutionType) {
        assert(!conflictResolved, "Already resolved!")
        conflictResolved = true
        resolutionCallback(resolution)
    }
}
