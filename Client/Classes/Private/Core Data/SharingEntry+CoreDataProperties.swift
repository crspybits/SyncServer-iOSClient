//
//  SharingEntry+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/4/18.
//
//

import Foundation
import CoreData


extension SharingEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharingEntry> {
        return NSFetchRequest<SharingEntry>(entityName: "SharingEntry")
    }

    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var sharingGroupName: String?
    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var masterVersion: Int64

}
