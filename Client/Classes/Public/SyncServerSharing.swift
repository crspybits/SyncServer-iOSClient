//
//  SyncServerSharing.swift
//  SyncServer
//
//  Created by Christopher G Prince on 8/24/18.
//

import Foundation
import SyncServer_Shared

public class SyncServerSharing {
    private init() {}
    public static let session = SyncServerSharing()
    
    public enum Response<T> {
        case success(T)
        case error(SyncServerError)
    }
    
    public func createSharingGroup(sharingGroupName:String? = nil, completion:@escaping (Response<SharingGroupId>)->()) {
        ServerAPI.session.createSharingGroup(sharingGroupName: sharingGroupName) { response in
            switch response {
            case .success(let result):
                completion(.success(result))
            case .error(let error):
                completion(.error(SyncServerError.otherError(error)))
            }
        }
    }
    
    public func updateSharingGroup(sharingGroupId: SharingGroupId, sharingGroupName:String, completion:@escaping (SyncServerError?)->()) {
    
        ServerAPI.session.index(sharingGroupId: sharingGroupId) { response in
            switch response {
            case .success(let result):                
                guard let masterVersion = result.masterVersion else {
                    completion(SyncServerError.unknownServerError)
                    return
                }
                
                ServerAPI.session.updateSharingGroup(sharingGroupId: sharingGroupId, masterVersion: masterVersion, sharingGroupName: sharingGroupName) { response in
                    switch response {
                    case .success(let result):
                        if result == nil {
                            completion(nil)
                        }
                        else {
                            completion(SyncServerError.generic("Master version updated."))
                        }
                    case .error(let error):
                        completion(SyncServerError.otherError(error))
                    }
                }
            case .error(let error):
                completion(SyncServerError.otherError(error))
            }
        }
    }
    
    public func removeSharingGroup(sharingGroupId: SharingGroupId, completion:@escaping (SyncServerError?)->()) {
        ServerAPI.session.index(sharingGroupId: sharingGroupId) { response in
            switch response {
            case .success(let result):
                guard let masterVersion = result.masterVersion else {
                    completion(SyncServerError.unknownServerError)
                    return
                }
                
                ServerAPI.session.removeSharingGroup(sharingGroupId: sharingGroupId, masterVersion: masterVersion) { response in
                    switch response {
                    case .success(let result):
                        if result == nil {
                            completion(nil)
                        }
                        else {
                            completion(SyncServerError.generic("Master version updated."))
                        }
                    case .error(let error):
                        completion(SyncServerError.otherError(error))
                    }
                }
            case .error(let error):
                completion(SyncServerError.otherError(error))
            }
        }
    }
    
    public func removeUserFromSharingGroup(sharingGroupId: SharingGroupId, completion:@escaping (SyncServerError?)->()) {
        ServerAPI.session.index(sharingGroupId: sharingGroupId) { response in
            switch response {
            case .success(let result):
                guard let masterVersion = result.masterVersion else {
                    completion(SyncServerError.unknownServerError)
                    return
                }
                
                ServerAPI.session.removeUserFromSharingGroup(sharingGroupId: sharingGroupId, masterVersion: masterVersion) { response in
                    switch response {
                    case .success(let result):
                        if result == nil {
                            completion(nil)
                        }
                        else {
                            completion(SyncServerError.generic("Master version updated."))
                        }
                    case .error(let error):
                        completion(SyncServerError.otherError(error))
                    }
                }
            case .error(let error):
                completion(SyncServerError.otherError(error))
            }
        }
    }
}
