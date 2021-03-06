//
//  SyncServerConflict.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/11/18.
//

import Foundation
import SMCoreLib

/// In the following the term `content` refers to either appMetaData or file data contents.

/// Download deletions can conflict with file uploads and/or appMetaData uploads. A server download deletion and a client file upload deletion don't conflict (it's just two people trying to delete at about the same time, which is fine).
public enum DownloadDeletionResolution {
    
    public enum ContentUploadResolution {
        /// It is an error to select this for a conflict with a purely appMetaData upload -- because a pure appMetaData upload cannot undelete or restore the content of a file that has already been deleted.
        case keepContentUpload
        
        case removeContentUpload
    }
    
    /// Deletes the existing content upload.
    case acceptDownloadDeletion
    
    /// For a file with a non-nil fileGroupUUID, this will also reject all pending download deletions for files with the same fileGroupUUID.
    case rejectDownloadDeletion(ContentUploadResolution)
}

/// Content downloads can conflict with content upload(s) and/or an upload deletion. See the conflictType of the specific `SyncServerConflict`.
public enum ContentDownloadResolution {
    /// This is used in `rejectContentDownload` below.
    public struct UploadResolution : OptionSet {
        public let rawValue: Int
        public init(rawValue:Int){ self.rawValue = rawValue}
        
        /// If you are going to use `rejectContentDownload` (see below), this is the typical upload resolution.
        public static let keepAll:UploadResolution = [keepContentUploads, keepUploadDeletions]
        
        /// Remove any conflicting local content uploads and/or upload deletions.
        public static let removeAll = UploadResolution(rawValue: 0)
        
        /// Not having this option means to remove your conflicting content uploads
        public static let keepContentUploads = UploadResolution(rawValue: 1 << 0)
        
        public var keepContentUploads:Bool {
            return self.contains(UploadResolution.keepContentUploads)
        }
        
        public var removeContentUploads:Bool {
            return !self.contains(UploadResolution.keepContentUploads)
        }
        
        /// Not having this option means to remove your conflicting upload deletions.
        public static let keepUploadDeletions = UploadResolution(rawValue: 1 << 1)
        
        public var keepUploadDeletions:Bool {
            return self.contains(UploadResolution.keepUploadDeletions)
        }
        
        public var removeUploadDeletions:Bool {
            return !self.contains(UploadResolution.keepUploadDeletions)
        }
    }
    
    /// Deletes any conflicting content upload and/or upload deletion.
    case acceptContentDownload
    
    case rejectContentDownload(UploadResolution)
}

public enum ServerContentType {
    case appMetaData
    case file(SMRelativeLocalURL)
    
    /// Both a file download and an appMetaData update.
    case both(downloadURL: SMRelativeLocalURL)
}

/**
    Because downloads are higher-priority (than uploads) with the SyncServer, all conflicts effectively originate from a server download operation: A download-deletion, a file-download, or an appMetaData download. The type of server operation will be apparent from the context.
 
    And the conflict is between the server operation and a local, client operation.
*/
public enum ConflictingClientOperation: Equatable {
    public enum ContentType {
        case appMetaData
        case file
        
        /// There are both appMetaData and file uploads conflicting
        case both
    }

    case uploadDeletion
    case contentUpload(ContentType)
    
    /// There are both upload deletions and content uploads conflicting.
    case both

    public static func == (lhs: ConflictingClientOperation, rhs: ConflictingClientOperation) -> Bool {
        switch lhs {
        case .uploadDeletion:
            if case .uploadDeletion = rhs {
                return true
            }

        case .contentUpload(let contentTypeLHS):
            if case .contentUpload(let contentTypeRHS) = rhs, contentTypeLHS == contentTypeRHS {
                return true
            }
            
        case .both:
            if case .both = rhs {
                return true
            }
        }
        
        return false
    }
}

/// When you receive a conflict in a callback method, you must resolve the conflict by calling resolveConflict.
public class SyncServerConflict<R> {
    typealias callbackType = ((R)->())?
    
    var conflictResolved:Bool = false
    var resolutionCallback:((R)->())!
    
    init(conflictType: ConflictingClientOperation, resolutionCallback:callbackType) {
        self.conflictType = conflictType
        self.resolutionCallback = resolutionCallback
    }
    
    public private(set) var conflictType:ConflictingClientOperation!
    
    /// Don't call this more than once!
    public func resolveConflict(resolution:R) {
        assert(!conflictResolved, "Already resolved!")
        conflictResolved = true
        resolutionCallback(resolution)
    }
}

