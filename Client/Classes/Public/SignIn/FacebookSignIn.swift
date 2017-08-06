//
//  FacebookUserSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/11/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Enables you to sign in as a Facebook user to (a) create a new sharing user (must have an invitation from another SyncServer user), or (b) sign in as an existing sharing user.

import Foundation
import SMCoreLib
import FacebookLogin
import FacebookCore
import SyncServer_Shared

public class FacebookCredentials : GenericCredentials {
    fileprivate var accessToken:AccessToken!
    fileprivate var userProfile:UserProfile!
    
    public var userId:String {
        return userProfile.userId
    }
    
    public var username:String {
        return userProfile.fullName!
    }
    
    public var uiDisplayName:String {
        return userProfile.fullName!
    }
    
    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = ServerConstants.AuthTokenType.FacebookToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = accessToken.authenticationToken
        return result
    }

    enum RefreshError : Error {
    case noRefreshAvailable
    }
    
    public func refreshCredentials(completion: @escaping (Error?) ->()) {
        completion(RefreshError.noRefreshAvailable)
        // The AccessToken refresh method doesn't work if the access token has expired. So, I think it's not useful here.
    }
}

public class FacebookSyncServerSignIn : GenericSignIn {
    public var signOutDelegate:GenericSignOutDelegate?
    public var delegate:GenericSignInDelegate?
    public var managerDelegate:SignInManagerDelegate!
    private let signInOutButton:FacebookSignInButton!
    
    public init() {
        signInOutButton = FacebookSignInButton()
        signInOutButton.signIn = self
    }
    
    public var signInTypesAllowed:SignInType = .sharingUser
    
    public func appLaunchSetup(silentSignIn: Bool, withLaunchOptions options:[UIApplicationLaunchOptionsKey : Any]?) {
    
        SDKApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: options)
        
        if silentSignIn {
            AccessToken.refreshCurrentToken() { (accessToken, error) in
                if error == nil {
                    Log.msg("FacebookSignIn: Sucessfully refreshed current access token")
                    self.completeSignInProcess()
                }
                else {
                    self.signUserOut()
                    Log.error("FacebookSignIn: Error refreshing access token: \(error!)")
                }
            }
        }
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return SDKApplicationDelegate.shared.application(app, open: url, options: options)
    }
    
    @discardableResult
    public func setupSignInButton(params:[String:Any]? = nil) -> TappableButton? {
        return signInOutButton
    }
    
    public var signInButton:TappableButton? {
        return signInOutButton
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
        signOutDelegate?.userWasSignedOut(signIn: self)
        delegate?.userActionOccurred(action: .userSignedOut, signIn: self)
        managerDelegate?.signInStateChanged(to: .signedOut, for: self)
    }
    
    // Call this on a successful sign in to Facebook.
    fileprivate func completeSignInProcess(success: (()->())? = nil, failure: (()->())? = nil) {
        managerDelegate?.signInStateChanged(to: .signedIn, for: self)

        guard let userAction = delegate?.shouldDoUserAction(signIn: self) else {
            // This occurs if we don't have a delegate (e.g., on a silent sign in). But, we need to set up creds-- because this is what gives us credentials for connecting to the SyncServer.
            SyncServerUser.session.creds = credentials
            success?()
            return
        }
        
        switch userAction {
        case .signInExistingUser:
            SyncServerUser.session.checkForExistingUser(creds: credentials!) {
                (checkForUserResult, error) in
                if error == nil {
                    switch checkForUserResult! {
                    case .noUser:
                        self.delegate?.userActionOccurred(action:
                            .userNotFoundOnSignInAttempt, signIn: self)
                        failure?()
                        
                    case .owningUser:
                        // This should never happen!
                        failure?()
                        Log.error("Somehow a Facebook user signed in as an owning user!!")
                        
                    case .sharingUser(sharingPermission: let permission):
                        self.delegate?.userActionOccurred(action: .existingUserSignedIn(permission), signIn: self)
                        success?()
                    }
                }
                else {
                    // TODO: *0* Give the user an error indication.
                    Log.error("Error checking for existing user: \(String(describing: error))")
                    failure?()
                }
            }
            
        case .createOwningUser:
            // Facebook users cannot be owning users! They don't have cloud storage.
            failure?()
            Log.error("Somehow a Facebook user attempted to create an owning user!!")
            
        case .createSharingUser(invitationCode: let invitationCode):
            SyncServerUser.session.redeemSharingInvitation(creds: credentials!, invitationCode: invitationCode) { error in
                if error == nil {
                    self.delegate?.userActionOccurred(action: .sharingUserCreated, signIn: self)
                    success?()
                }
                else {
                    failure?()
                }
            }
            
        case .none:
            failure?()
        }
    }
}

private class FacebookSignInButton : UIControl, Tappable {
    var signInButton:LoginButton!
    weak var signIn: FacebookSyncServerSignIn!
    private let permissions = [ReadPermission.publicProfile]
    
    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = LoginButton(readPermissions: permissions)
        super.init(frame: signInButton.frame)
        addSubview(signInButton)
        signInButton.autoresizingMask = [.flexibleWidth]
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The incoming point is relative to the coordinate system of the button if the button is at (0,0)
        var zeroStartFrame = frame
        zeroStartFrame.origin = CGPoint(x: 0, y: 0)
        if zeroStartFrame.contains(point) {
            return self
        }
        else {
            return nil
        }
    }
    
    public func tap() {
        if signIn.userIsSignedIn {
            signIn.signUserOut()
        }
        else {
            signIn.managerDelegate?.signInStateChanged(to: .signInStarted, for: signIn)
            
            let loginManager = LoginManager()
            loginManager.logIn(permissions, viewController: nil) { (loginResult) in
                switch loginResult {
                case .failed(let error):
                    print(error)
                    self.signIn.signUserOut()
                    
                case .cancelled:
                    print("User cancelled login.")
                    self.signIn.signUserOut()
                    
                case .success(_, _, _):
                    print("Logged in!")
                    
                    // Seems the UserProfile isn't loaded yet.
                    UserProfile.fetch(userId: AccessToken.current!.userId!) { fetchResult in
                        switch fetchResult {
                        case .success(_):
                            self.signIn.completeSignInProcess(failure: {
                                self.signIn.signUserOut()
                            })
                        case .failed(let error):
                            Log.error("Error fetching UserProfile: \(error)")
                            self.signIn.signUserOut()
                        }
                    }
                }
            }
        }
    }
}
