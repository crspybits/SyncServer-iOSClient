//
//  DownloadFileTracker+CoreDataProperties.swift
//  Pods
//
//  Created by Christopher G Prince on 8/26/17.
//
//

import Foundation
import CoreData


extension DownloadFileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadFileTracker> {
        return NSFetchRequest<DownloadFileTracker>(entityName: "DownloadFileTracker")
    }

    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var creationDate: NSDate?
    @NSManaged public var updateDate: NSDate?

}
