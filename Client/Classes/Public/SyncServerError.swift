//
//  SyncServerError.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/3/18.
//

import Foundation

// Many of these only have internal meaning to the client. Some are documented because they can be useful to the code using the client.
public enum SyncServerError: Error {
    // The network connection was lost.
    case noNetworkError
    
    case syncIsOperating
    case alreadyDownloadingAFile
    case alreadyUploadingAFile
    case couldNotFindFileUUID(String)
    case versionForFileWasNil(fileUUUID: String)
    case noRefreshAvailable
    case couldNotCreateResponse
    case couldNotCreateRequest
    case didNotGetDownloadURL
    case couldNotMoveDownloadFile
    case couldNotCreateNewFileForDownload
    case obtainedAppMetaDataButWasNotString
    case noExpectedResultKey
    case nilResponse
    case couldNotObtainHeaderParameters
    case resultURLObtainedWasNil
    case errorConvertingServerResponse
    case jsonSerializationError(Error)
    case urlSessionError(Error)
    case couldNotGetHTTPURLResponse
    case non200StatusCode(Int)
    case badCheckCreds
    case unknownServerError
    case coreDataError(Error)
    case generic(String)
    
#if TEST_REFRESH_FAILURE
    case testRefreshFailure
#endif

    case credentialsRefreshError
}