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
    var dropboxSignIn:DropboxSyncServerSignIn!
    
    static let session = SetupSignIn()
    
    private init() {
    }
    
    func appLaunch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        var googleServerClientId:String!
        var googleAppClientId:String!
        var dropboxAppKey:String!
        
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleClientId") {
            googleAppClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleServerClientId") {
            googleServerClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "DropboxAppKey") {
            dropboxAppKey = value
        }
    
        googleSignIn = GoogleSyncServerSignIn(serverClientId: googleServerClientId, appClientId: googleAppClientId)
        SignInManager.session.addSignIn(googleSignIn, launchOptions: options)
        
        facebookSignIn = FacebookSyncServerSignIn()
        SignInManager.session.addSignIn(facebookSignIn, launchOptions: options)
        
        dropboxSignIn = DropboxSyncServerSignIn(appKey: dropboxAppKey)
        SignInManager.session.addSignIn(dropboxSignIn, launchOptions: options)
    }
}
