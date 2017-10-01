
//
//  SignInManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/23/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared

public class SignInManager {
    // These must be stored in user defaults-- so that if they delete the app, we lose it, and can start again. Storing both the currentUIDisplayName and userId because the userId (at least for Google) is just a number and not intelligible in the UI.
    public static var currentUIDisplayName = SMPersistItemString(name:"SignInManager.currentUIDisplayName", initialStringValue:"",  persistType: .userDefaults)
    public static var currentUserId = SMPersistItemString(name:"SignInManager.currentUserId", initialStringValue:"",  persistType: .userDefaults)
    
    // The class name of the current GenericSignIn
    static var currentSignInName = SMPersistItemString(name:"SignInManager.currentSignIn", initialStringValue:"",  persistType: .userDefaults)

    public static let session = SignInManager()
    
    public var signInStateChanged:TargetsAndSelectors = NSObject()
    
    private init() {
        signInStateChanged.resetTargets!()
    }
    
    fileprivate var alternativeSignIns = [GenericSignIn]()
    
    public func getSignIns(`for` signInType: SignInType) -> [GenericSignIn]  {
        var result = [GenericSignIn]()
        
        for signIn in alternativeSignIns {
            if signInType == .both || signIn.signInTypesAllowed.contains(signInType) {
                result += [signIn]
            }
        }
        
        return result
    }
    
    // Set this to establish the current SignIn mechanism in use in the app.
    public var currentSignIn:GenericSignIn? {
        didSet {
            if currentSignIn == nil {
                SignInManager.currentSignInName.stringValue = ""
            }
            else {
                SignInManager.currentSignInName.stringValue = stringNameForSignIn(currentSignIn!)
            }
        }
    }
    
    fileprivate func stringNameForSignIn(_ signIn: GenericSignIn) -> String {
        // This gives "GenericSignIn"
        // String(describing: type(of: currentSignIn!))
        
        let mirror = Mirror(reflecting: signIn)
        return "\(mirror.subjectType)"
    }
    
    // A shorthand-- because it's often used.
    public var userIsSignIn:Bool {
        return currentSignIn?.userIsSignedIn ?? false
    }
    
    // At launch, you must set up all the SignIn's that you'll be presenting to the user. This will call their `appLaunchSetup` method.
    public func addSignIn(_ signIn:GenericSignIn, launchOptions options: [UIApplicationLaunchOptionsKey: Any]?) {
        // Make sure we don't already have an instance of this signIn
        let name = stringNameForSignIn(signIn)
        let result = alternativeSignIns.filter({stringNameForSignIn($0) == name})
        assert(result.count == 0)
        
        alternativeSignIns.append(signIn)
        signIn.managerDelegate = self
        let silentSignIn = SignInManager.currentSignInName.stringValue == name
        signIn.appLaunchSetup(silentSignIn: silentSignIn, withLaunchOptions: options)
    }
    
    // Based on the currently active signin method, this will call the corresponding method on that class.
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        for signIn in alternativeSignIns {
            if SignInManager.currentSignInName.stringValue == stringNameForSignIn(signIn) {
                return signIn.application(app, open: url, options: options)
            }
        }
        
        // 10/1/17; Up until today, I had this assert here. For some reason, I was assuming that if I got a `open url` call, the user *had* to be signed in. But this is incorrect. For example, I could get a call for a sharing invitation.
        // assert(false)
        
        return false
    }
}

extension SignInManager : SignInManagerDelegate {
    public func signInStateChanged(to state: SignInState, for signIn:GenericSignIn) {
        switch state {
        case .signInStarted:
            // Must not have any other signin's active when attempting to sign in.
            assert(currentSignIn == nil)
            // This is necessary to enable the `application(_ application: UIApplication!,...` method to be called during the sign in process.
            currentSignIn = signIn
            
        case .signedIn:
            // This is necessary for silent sign in's.
            currentSignIn = signIn
            
        case .signedOut:
            currentSignIn = nil
        }
        
        signInStateChanged.forEachTarget!() { (target, selector, dict) in
            if let targetObject = target as? NSObject {
                targetObject.performVoidReturn(selector)
            }
        }
    }
}

