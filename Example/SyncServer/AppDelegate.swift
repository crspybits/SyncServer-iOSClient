//
//  AppDelegate.swift
//  SyncServer
//
//  Created by Christopher Prince on 12/24/2016.
//  Copyright (c) 2016 Christopher Prince. All rights reserved.
//

// To use this app with a self-signed SSL certificate, you need to add a flag:
//  -D SELF_SIGNED_SSL

// To revoke Facebook permissions for app, go to: https://www.facebook.com/settings?tab=applications
// You can also go to https://developers.facebook.com/apps and reset the app secret. (And, of course, you need to update the app secret on your server).

import UIKit
import SMCoreLib
import SyncServer
import XCGLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Log.minLevel = .verbose
        
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        // On AWS: https://testing.syncserver.cprince.com
        let urlString = try! plist.getString(varName: "ServerURL")
        let serverURL = URL(string: urlString)!
        let cloudFolderName = try! plist.getString(varName: "CloudFolderName")
        
        var failoverURL:URL?
        if let failoverURLString = try? plist.getString(varName: "FailoverMessageURL") {
            failoverURL = URL(string: failoverURLString)
        }
        
        XCGLogger.default.setup(level: .verbose, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true)

        // Call this as soon as possible in your launch sequence.
        SyncServer.session.appLaunchSetup(withServerURL: serverURL, logger: XCGLogger.default, cloudFolderName:cloudFolderName, failoverMessageURL: failoverURL)
        
        SetupSignIn.session.appLaunch(options:launchOptions)
        
        // Need to do this ourselves-- if we let it happen automatically, we don't always have all of this setup done, above, before hand.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = ViewController.create()
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return SignInManager.session.application(app, open: url, options: options)
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        SyncServer.session.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

