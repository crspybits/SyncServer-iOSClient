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
    
    var status:DownloadFileTracker.Status {
        get {
            return DownloadFileTracker.Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    var dfts:[DownloadFileTracker] {
        if let downloads = downloads, let result = Array(downloads) as?  [DownloadFileTracker] {
            return result
        }
        return []
    }
    
    public class func newObject() -> NSManagedObject {
        let contentGroup = CoreData.sessionNamed(Constants.coreDataName).newObject(
            withEntityName: self.entityName()) as! DownloadContentGroup
        contentGroup.status = .notStarted
        return contentGroup
    }
    
    class func fetchObjectWithUUID(fileGroupUUID:String) -> DownloadContentGroup? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? DownloadContentGroup
    }
    
    // If a DownloadContentGroup exists with this fileGroupUUID, adds this dft to it. Otherwise, creates one and adds it. The case were fileGroupUUID is nil is to deal with not having a fileGroupUUID for a file-- to enable consistency with downloads.
    class func addDownloadFileTracker(_ dft: DownloadFileTracker, to fileGroupUUID:String?) {
        var group:DownloadContentGroup!
        if let fileGroupUUID = fileGroupUUID, let dcg = DownloadContentGroup.fetchObjectWithUUID(fileGroupUUID: fileGroupUUID) {
            group = dcg
        }
        else {
            group = DownloadContentGroup.newObject() as! DownloadContentGroup
            group.fileGroupUUID = fileGroupUUID
        }
        
        group.addToDownloads(dft)
    }
    
    func remove()  {        
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
