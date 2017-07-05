//
//  FacebookUserSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/11/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Enables you to sign in as a Facebook user to (a) create a new sharing user (must have an invitation from another SyncServer user), or (b) sign in as an existing sharing user.

import Foundation
import SyncServer
import SMCoreLib
import FacebookLogin
import FacebookCore

public class FacebookCredentials : GenericCredentials {
    fileprivate var accessToken:AccessToken!
    fileprivate var userProfile:UserProfile!
    
    public var userId:String = ""
    public var username:String = ""
    public var uiDisplayName:String = ""

    public var httpRequestHeaders:[String:String] {
        return [String:String]()
    }

    enum RefreshError : Error {
    case noRefreshAvailable
    }
    
    public func refreshCredentials(completion: @escaping (Error?) ->()) {
        completion(RefreshError.noRefreshAvailable)
        // The AccessToken refresh method doesn't work if the access token has expired. So, I think it's not useful here.
    }
}

public class FacebookSignIn : GenericSignIn {
    public var signOutDelegate:GenericSignOutDelegate?
    public var delegate:GenericSignInDelegate?
    public var managerDelegate:GenericSignInManagerDelegate!
    private let signInButton:FacebookSignInButton!
    
    private func getManagerDelegate() -> GenericSignInManagerDelegate {
        return managerDelegate
    }
    
    public init() {
        signInButton = FacebookSignInButton()
        signInButton.managerDelegate = getManagerDelegate
        signInButton.signIn = self
    }
    
    public func appLaunchSetup(silentSignIn: Bool, withLaunchOptions options:[UIApplicationLaunchOptionsKey : Any]?) {
    
        SDKApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: options)
        
        if silentSignIn {
            AccessToken.refreshCurrentToken() { (accessToken, error) in
                if error == nil {
                    Log.msg("FacebookSignIn: Sucessfully refreshed current access token")
                }
                else {
                    Log.error("FacebookSignIn: Error refreshing access token: \(error!)")
                }
            }
        }
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return SDKApplicationDelegate.shared.application(app, open: url, options: options)
    }
    
    public func getSignInButton(params:[String:Any]? = nil) -> TappableSignInButton? {
        return signInButton
    }
    
    public var userIsSignedIn: Bool {
        return AccessToken.current != nil
    }

    // Non-nil if userIsSignedIn is true.
    public var credentials:GenericCredentials? {
        if userIsSignedIn {
            let creds = FacebookCredentials()
            creds.accessToken = AccessToken.current
            creds.userProfile = UserProfile.current
            return creds
        }
        else {
            return nil
        }
    }

    public func signUserOut() {
        LoginManager().logOut()
    }
    
    /*
    override open var syncServerSignedInUser:SMUserCredentials? {
        get {
            if self.syncServerUserIsSignedIn {
                return .Facebook(userType: .SharingUser(owningUserId: self.currentOwningUserId), accessToken: FBSDKAccessToken.currentAccessToken().tokenString, userId: FBSDKAccessToken.currentAccessToken().userID, userName: self.fbUserName)
            }
            else {
                return nil
            }
        }
    }
    
    override open func syncServerSignOutUser() {
        self.reallyLogOut()
    }
    
    override open func syncServerRefreshUserCredentials() {
    }
    
    open func signInButton() -> UIButton {
        let fbLoginButton = FBSDKLoginButton()
        // fbLoginButton.readPermissions =  ["public_profile", "email", "user_friends"]
        fbLoginButton.readPermissions =  ["email"]
        fbLoginButton.delegate = self
            
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        fbLoginButton.addGestureRecognizer(longPress)
        
        return fbLoginButton
    }
    */
    @objc fileprivate func longPressAction() {
        /*
        if FBSDKAccessToken.currentAccessToken() != nil {
            self.reallyLogOut()
        }
        */
    }
}

extension FacebookSignIn : LoginButtonDelegate {
    public func loginButtonDidCompleteLogin(_ loginButton: LoginButton, result: LoginResult) {
        switch result {
        case .cancelled:
            Log.msg("FacebookSignIn: Cancelled sign in.")
            managerDelegate?.signInStateChanged(to: .signedOut, for: self)

        case .failed(let error):
            Log.msg("FacebookSignIn: Error signing in: \(error).")
            managerDelegate?.signInStateChanged(to: .signedOut, for: self)
            
        case .success(grantedPermissions: _, declinedPermissions: _, token: _):
            Log.msg("FacebookSignIn: Success signing in!")
            managerDelegate?.signInStateChanged(to: .signedIn, for: self)
        }
    }

    public func loginButtonDidLogOut(_ loginButton: LoginButton) {
        Log.msg("FacebookSignIn: Button did logout.")
        managerDelegate?.signInStateChanged(to: .signedOut, for: self)
    }
}

private class FacebookSignInButton : UIControl, TappableSignInButton {
    var signInButton:LoginButton!
    var managerDelegate:(()->GenericSignInManagerDelegate)!
    weak var signIn: FacebookSignIn!
    private let permissions = [ReadPermission.publicProfile]

    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = LoginButton(readPermissions: permissions)
        super.init(frame: signInButton.frame)
        addSubview(signInButton)
        signInButton.autoresizingMask = [.flexibleWidth]
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self
    }
    
    public func tap() {
        if signIn.userIsSignedIn {
            signIn.signUserOut()
        }
        else {
            managerDelegate?().signInStateChanged(to: .signInStarted, for: signIn)
            
            let loginManager = LoginManager()
            loginManager.logIn(permissions, viewController: nil) { (loginResult) in
                switch loginResult {
                case .failed(let error):
                    print(error)
                case .cancelled:
                    print("User cancelled login.")
                case .success(let grantedPermissions, let declinedPermissions, let accessToken):
                    print("Logged in!")
                }
            }
        }
    }
}

/*
extension SMFacebookUserSignIn : FBSDKLoginButtonDelegate {
    public func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
    
        Log.msg("result: \(result); error: \(error)")
        
        if !result.isCancelled && error == nil {
            self.finishSignIn()
        }
    }

    public func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        self.completeReallyLogOut()
    }
    
    fileprivate func finishSignIn() {
        Log.msg("FBSDKAccessToken.currentAccessToken().userID: \(FBSDKAccessToken.currentAccessToken().userID)")
        
        // Adapted from http://stackoverflow.com/questions/29323244/facebook-ios-sdk-4-0how-to-get-user-email-address-from-fbsdkprofile
        let parameters = ["fields" : "email, id, name"]
        FBSDKGraphRequest(graphPath: "me", parameters: parameters).startWithCompletionHandler { (connection:FBSDKGraphRequestConnection!, result: AnyObject!, error: NSError!) in
            Log.msg("result: \(result); error: \(error)")
            
            if nil == error {
                if let resultDict = result as? [String:AnyObject] {
                    // I'm going to prefer the email address, if we get it, just because it's more distinctive than the name.
                    if resultDict["email"] != nil {
                        self.fbUserName = resultDict["email"] as? String
                    }
                    else {
                        self.fbUserName = resultDict["name"] as? String
                    }
                }
            }
            
            Log.msg("self.currentOwningUserId: \(self.currentOwningUserId)")
            
            let syncServerFacebookUser = SMUserCredentials.Facebook(userType: .SharingUser(owningUserId: self.currentOwningUserId), accessToken: FBSDKAccessToken.currentAccessToken().tokenString, userId: FBSDKAccessToken.currentAccessToken().userID, userName: self.fbUserName)
            
            // We are not going to allow the user to create a new sharing user without an invitation code. There just doesn't seem any point: They wouldn't have any access capabilities. So, if we don't have an invitation code, check to see if this user is already on the system.
            let sharingInvitationCode = self.delegate.smUserSignIn(getSharingInvitationCodeForUserSignIn: self)
            
            if sharingInvitationCode == nil {
                self.signInWithNoInvitation(facebookUser: syncServerFacebookUser)
            }
            else {
                // Going to redeem the invitation even if we get an error checking for email/name (username). The username is optional.
                
                // redeemSharingInvitation creates a new user if needed at the same time as redeeming invitation.
                // Success on redeeming does the sign callback in process.
                /*
                SMSyncServerUser.session.redeemSharingInvitation(invitationCode: sharingInvitationCode!, userCreds: syncServerFacebookUser) { (linkedOwningUserId, error) in
                    if error == nil {
                        // Now, when the Facebook creds get sent to the server, they'll have this linkedOwningUserId.
                        self.currentOwningUserId = linkedOwningUserId
                        Log.msg("redeemSharingInvitation self.currentOwningUserId: \(self.currentOwningUserId); linkedOwningUserId: \(linkedOwningUserId)")
                        
                        self.delegate.smUserSignIn(userJustSignedIn: self)
                    
                        // If we could not redeem the invitation (couldNotRedeemSharingInvitation is true), we want to set the invitation to nil-- it was bad. If we could redeem it, we also want to set it to nil-- no point in trying to redeem it again.
                        self.delegate.smUserSignIn(resetSharingInvitationCodeForUserSignIn: self)
                    }
                    else if error != nil {
                        // TODO: Give them a UI error message.
                        // Hmmm. We have an odd state here. If it was a new user, we created the user, but we couldn't redeem the invitation. What to do??
                        Log.error("Failed redeeming invitation.")
                        self.reallyLogOut()
                    }
                }*/
            }
        }
    }
    
    fileprivate func signInWithNoInvitation(facebookUser:SMUserCredentials) {
        if self.currentOwningUserId == nil {
            // No owning user id; need to select which one we're going to use.
            /*
            SMSyncServerUser.session.getLinkedAccountsForSharingUser(facebookUser) { (linkedAccounts, error) in
                if error == nil {
                    self.delegate.smUserSignIn(userSignIn: self, linkedAccountsForSharingUser: linkedAccounts!, selectLinkedAccount: { (internalUserId) in
                        self.currentOwningUserId = internalUserId
                        self.signInWithOwningUserId(facebookUser: facebookUser)
                    })
                }
                else {
                    Log.error("Failed getting linked accounts.")
                    self.reallyLogOut()
                }
            }*/
        }
        else {
            self.signInWithOwningUserId(facebookUser: facebookUser)
        }
    }
    
    fileprivate func signInWithOwningUserId(facebookUser:SMUserCredentials) {
        SMSyncServerUser.session.checkForExistingUser(
            facebookUser, completion: { error in
            
            if error == nil {
                self.delegate.smUserSignIn(userJustSignedIn: self)
            }
            else {
                // TODO: This does not necessarily the user is not on the system. E.g., on a server crash or a network failure, we'll also get here. Need to check an error return code from the server.
                // TODO: Give them an error message. Tell them they need an invitation from user on the system first.
                Log.error("User not on the system: Need an invitation!")
                self.reallyLogOut()
            }
        })
    }
    
    // It seems really hard to fully logout!!! The following helps.
    fileprivate func reallyLogOut() {
        let deletepermission = FBSDKGraphRequest(graphPath: "me/permissions/", parameters: nil, HTTPMethod: "DELETE")
        deletepermission.startWithCompletionHandler({ (connection, result, error) in
            print("the delete permission is \(result)")
            FBSDKLoginManager().logOut()
            self.completeReallyLogOut()
        })
    }
    
    fileprivate func completeReallyLogOut() {
        self.delegate.smUserSignIn(userJustSignedOut: self)
        
        // So that the next time we sign in, we get a choice of which owningUserId's we'll use if there is more than one.
        self.currentOwningUserId = nil
    }
}
*/
