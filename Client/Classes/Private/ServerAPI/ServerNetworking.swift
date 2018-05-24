//
//  ServerNetworking.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/29/15.
//  Copyright © 2015 Christopher Prince. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared
import CoreTelephony

protocol ServerNetworkingDelegate : class {
    // Key/value pairs to be added to the outgoing HTTP header for authentication
    func serverNetworkingHeaderAuthentication(forServerNetworking: Any?) -> [String:String]?
}

class ServerNetworking : NSObject {
    static let session = ServerNetworking()
    var minimumServerVersion:ServerVersion?
    weak var syncServerDelegate:SyncServerDelegate?
    private weak var _delegate:ServerNetworkingDelegate?
    private var haveCellularData: Bool?
    private let cellState = CTCellularData.init()

    var delegate:ServerNetworkingDelegate? {
        get {
            return _delegate
        }
        set {
            ServerNetworkingLoading.session.delegate = newValue
            _delegate = newValue
        }
    }
    
    func appLaunchSetup() {
        // TODO: *3* How can I have a networking spinner in the status bar? See https://github.com/crspybits/SyncServer-iOSClient/issues/7
        
        // See https://stackoverflow.com/questions/26357954/how-to-tell-if-the-user-turned-off-cellular-data-for-my-app?noredirect=1&lq=1 and https://stackoverflow.com/questions/22563526/how-do-i-know-if-cellular-access-for-my-ios-app-is-disabled
        cellState.cellularDataRestrictionDidUpdateNotifier = { dataRestrictedState in
            switch dataRestrictedState {
            case .notRestricted:
                self.haveCellularData = true
            case .restricted:
                self.haveCellularData = false
            case .restrictedStateUnknown:
                break
            }
        }
    }
    
    func sendRequestUsing(method: ServerHTTPMethod, toURL serverURL: URL, timeoutIntervalForRequest:TimeInterval? = nil,
        completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
        
        sendRequestTo(serverURL, method: method, timeoutIntervalForRequest:timeoutIntervalForRequest) { (serverResponse, statusCode, error) in
            completion?(serverResponse, statusCode, error)
        }
    }

    func upload(file:ServerNetworkingLoadingFile, fromLocalURL localURL: URL, toServerURL serverURL: URL, method: ServerHTTPMethod, completion: ((HTTPURLResponse?, _ statusCode:Int?, SyncServerError?)->())?) {
    
        // 5/21/18; I'm going to attempt to fix https://github.com/crspybits/SharedImages/issues/110 by just taking this out. I'm wondering if I'm getting false indications of a lack of a network. Use it as a diagnostic after an error instead.
        /*
        guard Network.session().connected() else {
            completion?(nil, nil, .noNetworkError)
            return
        }
        */
        
        ServerNetworkingLoading.session.upload(file: file, fromLocalURL: localURL, toServerURL: serverURL, method: method) {[unowned self] (serverResponse, statusCode, error) in
        
            if let headers = serverResponse?.allHeaderFields, !self.serverVersionIsOK(headerFields: headers) {
                return
            }
            
            guard error == nil else {
                self.checkForNetworkAndReport()
                completion?(nil, nil, error)
                return
            }
            
            completion?(serverResponse, statusCode, error)
        }
    }
    
    private func serverVersionIsOK(headerFields: [AnyHashable: Any]) -> Bool {
        var serverVersion: ServerVersion?
        if let version = headerFields[ServerConstants.httpResponseCurrentServerVersion] as? String {
            serverVersion = ServerVersion(rawValue: version)
        }
        
        if minimumServerVersion == nil {
            // Client doesn't care which version of the server they are using.
            return true
        }
        else if serverVersion == nil || serverVersion! < minimumServerVersion! {
            // Either: a) Client *does* care, but server isn't versioned, or
            // b) the actual server version is less than what the client needs.
            Thread.runSync(onMainThread: {
                self.syncServerDelegate?.syncServerErrorOccurred(error:
                    .badServerVersion(actualServerVersion: serverVersion))
            })
            return false
        }
        
        return true
    }
    
    public func download(file: ServerNetworkingLoadingFile, fromServerURL serverURL: URL, method: ServerHTTPMethod, completion:((SMRelativeLocalURL?, _ serverResponse:HTTPURLResponse?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {

        // 5/21/18; I'm going to attempt to fix https://github.com/crspybits/SharedImages/issues/110 by just taking this out. I'm wondering if I'm getting false indications of a lack of a network. Use it as a diagnostic after an error instead.
        /*
        guard Network.session().connected() else {
            completion?(nil, nil, nil, .noNetworkError)
            return
        }
        */
        
        ServerNetworkingLoading.session.download(file: file, fromServerURL: serverURL, method: method) { (url, urlResponse, status, error) in

            // Check first to see if we've got a bad server version. If we do, all bets are off-- `serverVersionIsOK` reports an error, and we'll return *without* calling the callback, since this is rather severe.
            if let headers = urlResponse?.allHeaderFields, !self.serverVersionIsOK(headerFields: headers) {
                return
            }
            
            if error == nil {
                guard url != nil else {
                    completion?(nil, nil, urlResponse?.statusCode, .didNotGetDownloadURL)
                    return
                }
                completion?(url, urlResponse, urlResponse?.statusCode, nil)
            }
            else {
                // There was an error-- check to see if it was due to network issues.
                self.checkForNetworkAndReport()
                completion?(nil, nil, nil, error)
            }
        }
    }
    
    private func sendRequestTo(_ serverURL: URL, method: ServerHTTPMethod, dataToUpload:Data? = nil, timeoutIntervalForRequest:TimeInterval? = nil, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
    
        // 5/21/18; I'm going to attempt to fix https://github.com/crspybits/SharedImages/issues/110 by just taking this out. I'm wondering if I'm getting false indications of a lack of a network. Use it as a diagnostic after an error instead.
        /*
        guard Network.session().connected() else {
            completion?(nil, nil, .noNetworkError)
            return
        }
        */
    
        let sessionConfiguration = URLSessionConfiguration.default
        if timeoutIntervalForRequest != nil {
            sessionConfiguration.timeoutIntervalForRequest = timeoutIntervalForRequest!
        }
        
        sessionConfiguration.httpAdditionalHeaders = self.delegate?.serverNetworkingHeaderAuthentication(
                forServerNetworking: self)
        Log.msg("httpAdditionalHeaders: \(String(describing: sessionConfiguration.httpAdditionalHeaders))")
        
        // If needed, use a delegate here to track upload progress.
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        
        // Data uploading task. We could use NSURLSessionUploadTask instead of NSURLSessionDataTask if we needed to support uploads in the background
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        request.httpBody = dataToUpload
        
        Log.msg("sendRequestTo: serverURL: \(serverURL)")
        
        let uploadTask:URLSessionDataTask = session.dataTask(with: request) { (data, urlResponse, error) in
            self.processResponse(data: data, urlResponse: urlResponse, error: error, completion: completion)
        }
        
        uploadTask.resume()
    }
    
    private func processResponse(data:Data?, urlResponse:URLResponse?, error: Error?, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
        if error == nil {
            // With an HTTP or HTTPS request, we get HTTPURLResponse back. See https://developer.apple.com/reference/foundation/urlsession/1407613-datatask
            guard let response = urlResponse as? HTTPURLResponse else {
                completion?(nil, nil, .couldNotGetHTTPURLResponse)
                return
            }
            
            // Treating unauthorized specially because we attempt a credentials refresh in some cases when we get this.
            if response.statusCode == HTTPStatus.unauthorized.rawValue {
                completion?(nil, response.statusCode, nil)
                return
            }
            
            if serverVersionIsOK(headerFields: response.allHeaderFields) {
                var json:Any?
                do {
                    try json = JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
                } catch (let error) {
                    Log.error("processResponse: Error in JSON conversion: \(error); statusCode= \(response.statusCode)")
                    completion?(nil, response.statusCode, .jsonSerializationError(error))
                    return
                }
                
                guard let jsonDict = json as? [String: Any] else {
                    completion?(nil, response.statusCode, .errorConvertingServerResponse)
                    return
                }
                
                var resultDict = jsonDict
                
                // Some responses (from endpoints doing sharing operations) have ServerConstants.httpResponseOAuth2AccessTokenKey in their header. Pass it up using the same key.
                if let accessTokenResponse = response.allHeaderFields[ServerConstants.httpResponseOAuth2AccessTokenKey] {
                    resultDict[ServerConstants.httpResponseOAuth2AccessTokenKey] = accessTokenResponse
                }
                
                Log.msg("No errors on upload: jsonDict: \(jsonDict)")
                completion?(resultDict, response.statusCode, nil)
            }
        }
        else {
            self.checkForNetworkAndReport()
            completion?(nil, nil, .urlSessionError(error!))
        }
    }
    
    // Only use this for a diagnostic purpose, not for a check to decide whether to make a network call. Returns true iff network was present.
    private func checkForNetworkAndReport() {
        // The ordering of checking here is a bit random. E.g., if running on an iPad that has no cellular connection, we'll might report no cellular data. But, I'm not sure if I'll actually get the affirmitive no in that case.
        
        if let haveCellularData = haveCellularData, !haveCellularData {
            Thread.runSync(onMainThread: {
                self.syncServerDelegate?.syncServerErrorOccurred(error: .noCellularDataConnection)
            })
        }
        else if !Network.session().connected() {
            Thread.runSync(onMainThread: {
                self.syncServerDelegate?.syncServerErrorOccurred(error: .noNetworkError)
            })
        }
    }
}

extension ServerNetworking : URLSessionDelegate {
#if SELF_SIGNED_SSL
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
#endif
}

