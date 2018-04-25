//
//  DownloadFileTracker.swift
//  Pods
//
//  Created by Christopher Prince on 2/24/17.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(DownloadFileTracker)
public class DownloadFileTracker: FileTracker, AllOperations {
    typealias COREDATAOBJECT = DownloadFileTracker
    
    enum Status : String {
    case notStarted
    case downloading
    case downloaded
    }
    
    var status:Status {
        get {
            return Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    public class func entityName() -> String {
        return "DownloadFileTracker"
    }
    
    public class func newObject() -> NSManagedObject {
        let dft = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! DownloadFileTracker
        dft.status = .notStarted
        dft.addAge()
        return dft
    }
    
    func remove()  {
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
