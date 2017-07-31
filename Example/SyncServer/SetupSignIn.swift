//
//  SetupSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 12/2/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer

class SetupSignIn {
    var googleSignIn:GoogleSyncServerSignIn!
    var facebookSignIn:FacebookSyncServerSignIn!
    static let session = SetupSignIn()
    
    private init() {
    }
    
    func appLaunch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        var serverClientId:String!
        var appClientId:String!
        
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleClientId") {
            appClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleServerClientId") {
            serverClientId = value
        }
    
        googleSignIn = GoogleSyncServerSignIn(serverClientId: serverClientId, appClientId: appClientId)
        SignInManager.session.addSignIn(googleSignIn, launchOptions: options)
        
        facebookSignIn = FacebookSyncServerSignIn()
        SignInManager.session.addSignIn(facebookSignIn, launchOptions: options)
    }
}
