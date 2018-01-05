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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        Log.minLevel = .verbose
        
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        let urlString = try! plist.getString(varName: "ServerURL")
        let serverURL = URL(string: urlString)!
        let cloudFolderName = try! plist.getString(varName: "CloudFolderName")
        
        // Call this as soon as possible in your launch sequence.
        SyncServer.session.appLaunchSetup(withServerURL: serverURL, cloudFolderName:cloudFolderName)
        
        SetupSignIn.session.appLaunch(options:launchOptions)
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
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

