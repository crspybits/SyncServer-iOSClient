//
//  FileTracker+CoreDataProperties.swift
//  Pods
//
//  Created by Christopher G Prince on 8/26/17.
//
//

import Foundation
import CoreData


extension FileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileTracker> {
        return NSFetchRequest<FileTracker>(entityName: "FileTracker")
    }

    @NSManaged public var appMetaData: String?
    @NSManaged public var fileSizeBytes: Int64
    @NSManaged public var fileUUIDInternal: String?
    @NSManaged public var fileVersionInternal: Int32
    @NSManaged public var localURLData: NSData?
    @NSManaged public var mimeType: String?
    @NSManaged public var statusRaw: String?

}
