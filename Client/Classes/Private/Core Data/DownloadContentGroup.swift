//
//  DownloadContentGroup+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 4/21/18.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(DownloadContentGroup)
public class DownloadContentGroup: NSManagedObject, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = DownloadContentGroup
    
    public static let UUID_KEY = "fileGroupUUID"

    public class func entityName() -> String {
        return "DownloadContentGroup"
    }
    
    public class func newObject() -> NSManagedObject {
        let contentGroup = CoreData.sessionNamed(Constants.coreDataName).newObject(
            withEntityName: self.entityName()) as! DownloadContentGroup
        return contentGroup
    }
    
    class func fetchObjectWithUUID(uuid:String) -> DownloadContentGroup? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? DownloadContentGroup
    }
}
