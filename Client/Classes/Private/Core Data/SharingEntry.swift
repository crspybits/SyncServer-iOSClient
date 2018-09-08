//
//  SharingEntry+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/4/18.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

// These represent an index of all sharing groups to which the user belongs.

@objc(SharingEntry)
public class SharingEntry: NSManagedObject, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = SharingEntry
    
    public static let UUID_KEY = "sharingGroupUUID"

    public class func entityName() -> String {
        return "SharingEntry"
    }
    
    public class func newObject() -> NSManagedObject {
        let se = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! SharingEntry
        se.deletedOnServer = false
        se.masterVersion = 0
        return se
    }
    
    class func fetchObjectWithUUID(uuid:String) -> SharingEntry? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? SharingEntry
    }
    
    class func masterVersionForUUID(_ uuid: String) -> MasterVersionInt? {
        if let result = fetchObjectWithUUID(uuid: uuid) {
            return result.masterVersion
        }
        else {
            return nil
        }
    }

    // Determine which, if any, sharing groups (a) have been deleted, or (b) have had name changes.
    
    struct Updates {
        let deletedOnServer:[SharingGroup]
        let newSharingGroups:[SharingGroup]
        let updatedSharingGroups:[SharingGroup]
    }
    
    class func update(sharingGroups: [SharingGroup]) -> Updates? {
        var deletedOnServer = [SharingGroup]()
        var newSharingGroups = [SharingGroup]()
        var updatedSharingGroups = [SharingGroup]()
        
        sharingGroups.forEach { sharingGroup in
            if let sharingGroupUUID = sharingGroup.sharingGroupUUID {
                if let deleted = sharingGroup.deleted, deleted {
                    if let found = fetchObjectWithUUID(uuid: sharingGroupUUID) {
                        if !found.deletedOnServer {
                            found.deletedOnServer = true
                            deletedOnServer += [sharingGroup]
                        }
                        // If we already know it's deleted, no need to do anything else.
                    }
                    else {
                        // Not found, and its deleted on server; lets create a SharingEntry and mark it as deleted.
                        let sharingEntry = SharingEntry.newObject() as! SharingEntry
                        sharingEntry.sharingGroupUUID = sharingGroupUUID
                        sharingEntry.deletedOnServer = true
                    }
                }
                else {
                    if let found = fetchObjectWithUUID(uuid: sharingGroupUUID) {
                        if found.sharingGroupName != sharingGroup.sharingGroupName {
                            found.sharingGroupName = sharingGroup.sharingGroupName
                            updatedSharingGroups += [sharingGroup]
                        }
                        if found.masterVersion != sharingGroup.masterVersion {
                            found.masterVersion = sharingGroup.masterVersion!
                        }
                    }
                    else {
                        let sharingEntry = SharingEntry.newObject() as! SharingEntry
                        sharingEntry.sharingGroupUUID = sharingGroupUUID
                        sharingEntry.sharingGroupName = sharingGroup.sharingGroupName
                        sharingEntry.masterVersion = sharingGroup.masterVersion!
                        newSharingGroups += [sharingGroup]
                    }
                }
            }
        }
        
        if deletedOnServer.count > 0 || newSharingGroups.count > 0 || updatedSharingGroups.count > 0 {
            return nil
        }
        else {
            return Updates(deletedOnServer: deletedOnServer, newSharingGroups: newSharingGroups, updatedSharingGroups: updatedSharingGroups)
        }
    }
}
