//
//  ServerNetworking+Loading.swift
//  SyncServer
//
//  Created by Christopher Prince on 5/29/17.
//
//

// Loading = Uploading & Downloading
// This class relies on Core Data.

import Foundation
import SMCoreLib
import SyncServer_Shared

// The reason for this class is given here: https://stackoverflow.com/questions/44224048/timeout-issue-when-downloading-from-aws-ec2-to-ios-app
// 12/31/17; Plus, I want downloading and uploading to work in the background-- see https://github.com/crspybits/SharedImages/issues/36

typealias DownloadCompletion = (SMRelativeLocalURL?, HTTPURLResponse?, _ statusCode:Int?, SyncServerError?)->()
typealias UploadCompletion = (HTTPURLResponse?, _ statusCode:Int?, SyncServerError?)->()

private enum CompletionHandler {
    case download(DownloadCompletion)
    case upload(UploadCompletion)
}

struct ServerNetworkingLoadingFile {
    let fileUUID:String
    let fileVersion: FileVersionInt
}

class ServerNetworkingLoading : NSObject {
    static let session = ServerNetworkingLoading()
    
    weak var authenticationDelegate:ServerNetworkingAuthentication?
    
    private var session:URLSession!
    fileprivate var completionHandlers = [URLSessionTask:CompletionHandler]()
    private var backgroundCompletionHandler:(()->())?

    private override init() {
        super.init()
        
        let appBundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        
        // https://developer.apple.com/reference/foundation/urlsessionconfiguration/1407496-background
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: "biz.SpasticMuffin.SyncServer." + appBundleName)
        
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            NetworkCached.deleteOldCacheEntries()
        }
    }
    
    func appLaunchSetup() {
        // Don't need do anything. The init did it all. This method is just here as a reminder and a means to set up the session when the app launches.
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.backgroundCompletionHandler = completionHandler
        DebugWriter.session.log("handleEventsForBackgroundURLSession")
    }
    
    // The caller must keep a strong reference to the returned object until at least all of the relevant ServerNetworkingDownloadDelegate delegate methods have been called upon completion of the download.
    private func downloadFrom(_ serverURL: URL, method: ServerHTTPMethod, andStart start:Bool=true) -> URLSessionDownloadTask {
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        
        request.allHTTPHeaderFields = authenticationDelegate?.headerAuthentication(forServerNetworking: self)
        
        print("downloadFrom: serverURL: \(serverURL)")
        
        let downloadTask = session.downloadTask(with: request)
        
        if start {
            downloadTask.resume()
        }
        
        return downloadTask
    }
    
    private func uploadTo(_ serverURL: URL, file localURL: URL, method: ServerHTTPMethod, andStart start:Bool=true) -> URLSessionUploadTask {
    
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        
        request.allHTTPHeaderFields = authenticationDelegate?.headerAuthentication(forServerNetworking: self)
        
        print("uploadTo: serverURL: \(serverURL)")
        
        let uploadTask = session.uploadTask(with: request, fromFile: localURL)
        
        if start {
            uploadTask.resume()
        }
        
        return uploadTask
    }
    
    // Start off by assuming we're going to lose the handler because the app moves into the background -- cache the upload or download.
    private func makeCache(file:ServerNetworkingLoadingFile, serverURL: URL) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let cachedResults = NetworkCached.newObject() as! NetworkCached
            
            // These serve as a key back to the client's info.
            cachedResults.fileUUID = file.fileUUID
            cachedResults.fileVersion = file.fileVersion
            
            // This is going to serve as a key -- so that when the results come back from the server, we can lookup the cache object.
            cachedResults.serverURLKey = serverURL.absoluteString
            
            cachedResults.save()
        }
    }
    
    func cacheResult(serverURLKey: URL, response:HTTPURLResponse, localURL: SMRelativeLocalURL? = nil) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            guard let cache = NetworkCached.fetchObjectWithServerURLKey(serverURLKey.absoluteString) else {
                return
            }
            
            if let localURL = localURL {
                cache.downloadURL = localURL
            }
            
            cache.dateTimeCached = Date() as NSDate
            cache.httpResponse = response
            cache.save()
        }
    }
    
    private func lookupAndRemoveCache(file:ServerNetworkingLoadingFile, download: Bool) -> (HTTPURLResponse, SMRelativeLocalURL?)? {
        
        var result:(HTTPURLResponse, SMRelativeLocalURL?)?
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            guard let fetchedCache = NetworkCached.fetchObjectWithUUID(file.fileUUID, andVersion: file.fileVersion) else {
                return
            }
            
            var resultCache:NetworkCached?
            
            if download {
                if fetchedCache.downloadURL != nil {
                    resultCache = fetchedCache
                }
            }
            else {
                resultCache = fetchedCache
            }
            
            if let response = resultCache?.httpResponse {
                result = (response, resultCache?.downloadURL)
                CoreData.sessionNamed(Constants.coreDataName).remove(resultCache!)
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
            }
        }
        
        return result
    }
    
    // In both of the following methods, the `ServerNetworkingLoadingFile` is redundant with the info in the serverURL, but is needed for caching purposes.
    
    // The file reference in the URL given in the completion handler has already been transferred to a more permanent location.
    func download(file:ServerNetworkingLoadingFile, fromServerURL serverURL: URL, method: ServerHTTPMethod, completion:@escaping DownloadCompletion) {
    
        // Before we go any further-- check to see if we have cached results.
        if let (response, url) = lookupAndRemoveCache(file: file, download: true) {
            let statusCode = response.statusCode
            DebugWriter.session.log("Using cached download result")
            
            // We are not caching error results, so set the error to nil.
            completion(url, response, statusCode, nil)
            return
        }
        
        makeCache(file: file, serverURL: serverURL)
        
        let task = downloadFrom(serverURL, method: method, andStart:false)
        Synchronized.block(self) {
            completionHandlers[task] = .download(completion)
        }
        task.resume()
    }
    
    func upload(file:ServerNetworkingLoadingFile, fromLocalURL localURL: URL, toServerURL serverURL: URL, method: ServerHTTPMethod, completion:@escaping UploadCompletion) {
    
        // Before we go any further-- check to see if we have cached results.
        if let (response, _) = lookupAndRemoveCache(file: file, download: false) {
            let statusCode = response.statusCode
            DebugWriter.session.log("Using cached upload result")
            // We are not caching error results, so set the error to nil.
            completion(response, statusCode, nil)
            return
        }
    
        makeCache(file: file, serverURL: serverURL)

        let task = uploadTo(serverURL, file: localURL, method: method, andStart:false)
        Synchronized.block(self) {
            completionHandlers[task] = .upload(completion)
        }
        task.resume()
    }
}

extension ServerNetworkingLoading : URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate, URLSessionDataDelegate {

#if SELF_SIGNED_SSL
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
#endif

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    
        Log.msg("download completed: location: \(location);  status: \(String(describing: (downloadTask.response as? HTTPURLResponse)?.statusCode))")
        
        var newFileURL:SMRelativeLocalURL?
        newFileURL = FilesMisc.createTemporaryRelativeFile()
        var returnError:SyncServerError?
        
        // Transfer the temporary file to a more permanent location. Have to do it right now. https://developer.apple.com/reference/foundation/urlsessiondownloaddelegate/1411575-urlsession
        if newFileURL == nil {
            returnError = .couldNotCreateNewFileForDownload
        }
        else {
            do {
                _ = try FileManager.default.replaceItemAt(newFileURL! as URL, withItemAt: location)
            }
            catch (let error) {
                Log.error("Could not move file: \(error)")
                returnError = .couldNotMoveDownloadFile
            }
        }
        
        // With an HTTP or HTTPS request, we get HTTPURLResponse back. See https://developer.apple.com/reference/foundation/urlsession/1407613-datatask
        let response = downloadTask.response as? HTTPURLResponse
        if response == nil {
            returnError = .couldNotGetHTTPURLResponse
        }
        
        var handler:CompletionHandler?
        Synchronized.block(self) {
            handler = completionHandlers[downloadTask]
        }
        
        if case .download(let completion)? = handler {
            completion(newFileURL, response, response?.statusCode, returnError)
        }
        else {
            // Must be running in the background-- since we don't have a handler.
            // We are not caching error results. Why bother? If we don't cache a result, the download will just need to be done again. And since there is an error, the download *will* need to be done again.
            if returnError == nil {
                cacheResult(serverURLKey: downloadTask.originalRequest!.url!, response: response!, localURL: newFileURL!)
                DebugWriter.session.log("Caching download result")
            }
        }
        
        Log.msg("Number of completion handlers in dictionary (start): \(completionHandlers.count)")
    }
    
    // For downloads: This gets called even when there was no error, but I believe only it (and not the `didFinishDownloadingTo` method) gets called if there is an error.
    // For uploads: This gets called to indicate successful completion or an error.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let response = task.response as? HTTPURLResponse
        Log.error("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")
        
        var handler:CompletionHandler?
        Synchronized.block(self) {
            handler = completionHandlers[task]
            completionHandlers[task] = nil
        }
        
        Log.msg("Number of completion handlers remaining in dictionary: \(completionHandlers.count)")
    
        if error != nil {
            Log.msg("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")
        }
        
        switch handler {
        case .none:
            // No handler. We must be running in the background. Ignore errors.
            if error == nil {
                switch task {
                case is URLSessionUploadTask:
                    cacheResult(serverURLKey: task.originalRequest!.url!, response: response!)
                     DebugWriter.session.log("Caching upload result")
                case is URLSessionDownloadTask:
                    // We will have already cached this.
                    break
                default:
                    // Should never get here!
                    break
                }
            }
        case .some(.download(let completion)):
            // Only need to call completion handler for a download if we have an error. In the normal case, we've already called it.
            if error != nil {
                completion(nil, response, response?.statusCode, .urlSessionError(error!))
            }
        case .some(.upload(let completion)):
            // For uploads, since this is called if we get an error or not, we always have to call the completion handler.
            let errorResult = error == nil ? nil : SyncServerError.urlSessionError(error!)
            completion(response, response?.statusCode, errorResult)
        }
    }
    
    // Apparently the following delegate method is how we get back body data from an upload task: "When the upload phase of the request finishes, the task behaves like a data task, calling methods on the session delegate to provide you with the server’s response—headers, status code, content data, and so on." (see https://developer.apple.com/documentation/foundation/nsurlsessionuploadtask).
    // But, how do we coordinate the status code and error info, apparently received in didCompleteWithError, with this??
    // 1/2/18; Because of this issue I've just now changed how the server upload response gives it's results-- the values now come back in an HTTP header key, just like the download.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    }
    
    // This gets called "When all events have been delivered, the system calls the urlSessionDidFinishEvents(forBackgroundURLSession:) method of URLSessionDelegate. At this point, fetch the backgroundCompletionHandler stored by the app delegate in Listing 3 and execute it. Listing 4 shows this process." (https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // "Note that because urlSessionDidFinishEvents(forBackgroundURLSession:) may be called on a secondary queue, it needs to explicitly execute the handler (which was received from a UIKit method) on the main queue." (https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)
        
        DebugWriter.session.log("urlSessionDidFinishEvents")
        
        Thread.runSync(onMainThread: {[unowned self] in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        })
    }
}
