//
//  SharingGroupUploadTracker+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/3/18.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(SharingGroupUploadTracker)
public class SharingGroupUploadTracker: Tracker, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = SharingGroupUploadTracker
    
    enum Status : String {
        case notStarted
        case uploading
        case uploaded
    }
    
    var status:Status {
        get {
            return Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    public enum SharingGroupOperation: String {
        case create
        case update
        case removeUser
    }
    
    var sharingGroupOperation:SharingGroupOperation {
        get {
            return SharingGroupOperation(rawValue: sharingGroupOperationInternal!)!
        }
        
        set {
            sharingGroupOperationInternal = newValue.rawValue
        }
    }
    
    public class func entityName() -> String {
        return "SharingGroupUploadTracker"
    }
    
    public class func newObject() -> NSManagedObject {
        let sgut = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! SharingGroupUploadTracker
        sgut.status = .notStarted
        return sgut
    }
}
