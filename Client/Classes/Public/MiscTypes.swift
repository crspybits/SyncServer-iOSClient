//
//  MiscTypes.swift
//  Pods
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

public typealias UUIDString = String

public protocol FileUUID {
    var fileUUID:UUIDString! {get}
}

// Attributes for a file being synced.
public struct SyncAttributes : FileUUID {
    public var mimeType:MimeType!

    public var fileUUID:UUIDString!

    // Supplied by the client (and only stored by the server, not used by the server otherwise). Used to indicate that a collection of files needs to be upload and downloaded as a group. Once a particular fileUUID is associated with a fileGroupUUID, it must always be associated with that fileGroupUUID. If not provided, then the file is a group of one and that fileUUID must always be a group of one (have a nil fileGroupUUID).
    public var fileGroupUUID:UUIDString?
    
    // 12/27/17; These only get used for responses from the server-- because it is the authority on dates.
    public var creationDate:Date?
    public var updateDate:Date?
    
    public var appMetaData:String?
    
    public init(fileUUID:UUIDString, mimeType:MimeType, creationDate: Date? = nil, updateDate: Date? = nil) {
        self.fileUUID = fileUUID
        self.mimeType = mimeType
        self.creationDate = creationDate
        self.updateDate = updateDate
    }
}



