//
//  ViewController.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/29/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib
@testable import SyncServer
import SyncServer_Shared

class ViewController: UIViewController, GoogleSignInUIProtocol {
    @IBOutlet weak var signInContainer: UIView!
    var googleSignInButton: TappableButton!
    var facebookSignInButton: TappableButton!
    var dropboxSignInButton:TappableButton!
    var syncServerEventOccurred: ((_ : SyncEvent)->())?
    @IBOutlet weak var testingOutcome: UILabel!
    
    static fileprivate var sharingInvitationUUID:SMPersistItemString = SMPersistItemString(name: "ViewController.sharingInvitationUUID", initialStringValue: "", persistType: .userDefaults)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        googleSignInButton = SetupSignIn.session.googleSignIn.setupSignInButton(params: ["delegate": self])
        SetupSignIn.session.googleSignIn.delegate = self
        
        facebookSignInButton = SetupSignIn.session.facebookSignIn.setupSignInButton(params:nil)
        facebookSignInButton.frameWidth = googleSignInButton.frameWidth
        SetupSignIn.session.facebookSignIn.delegate = self
        
        dropboxSignInButton = SetupSignIn.session.dropboxSignIn.setupSignInButton(params: ["viewController": self])
        dropboxSignInButton.frameSize = CGSize(width: googleSignInButton.frameWidth, height: googleSignInButton.frameHeight * 0.75)
        
        SetupSignIn.session.dropboxSignIn.delegate = self

        let signIn:SignIn = SignIn.createFromXib()!
        signInContainer.addSubview(signIn)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // So far, this needs to be run manually, after you've signed in. Also-- you may need to delete the current FileIndex contents in the database, and delete the app.
    @IBAction func testCredentialsRefreshAction(_ sender: Any) {
#if false
        self.testingOutcome.text = nil
        self.testingOutcome.setNeedsDisplay()

        SyncServer.session.eventsDesired = [.refreshingCredentials, .fileUploadsCompleted, .syncDone]
        SyncServer.session.delegate = self

        // These are a bit of a hack to do this testing.
        let user = SetupSignIn.session.googleSignIn.credentials as! GoogleCredentials
        user.accessToken = "foobar"
        SyncServerUser.session.creds = user
        
        var numberUploads = 0
        var refresh = 0
        var uploadsCompleted = 0
        
        syncServerEventOccurred = { event in
            switch event {
            case .syncDone:
                if refresh == 1 && uploadsCompleted == 1 {
                    self.testingOutcome.text = "success!"
                }
                else {
                    self.testingOutcome.text = "failed"
                }
                SyncManager.session.testingDelegate = nil
                
            case .refreshingCredentials:
                refresh += 1
                
            case .fileUploadsCompleted(numberOfFiles: let numberOfFiles):
                assert(numberOfFiles == numberUploads, "numberOfFiles: \(numberOfFiles); numberUploads: \(numberUploads)")
                uploadsCompleted += 1
                
            default:
                assert(false)
            }
        }
        
        SyncManager.session.testingDelegate = self
        
        syncServerSingleFileUploadCompleted = {
            numberUploads += 1
        }
        
        let url = SMRelativeLocalURL(withRelativePath: "UploadMe2.txt", toBaseURLType: .mainBundle)!
        let uuid = UUID().uuidString
        let attr = SyncAttributes(fileUUID: uuid, mimeType: .text)
        try! SyncServer.session.uploadImmutable(localFile: url, withAttributes: attr)
        SyncServer.session.sync()
#endif
    }
 
    @IBAction func createSharingInvitationAction(_ sender: Any) {
        guard let sharingGroups = SyncServerUser.session.sharingGroups, sharingGroups.count > 0, let sharingGroupId = sharingGroups[0].sharingGroupId else {
            Log.error("No sharing groups!")
            return
        }
        
        Alert.show(message: "Press 'OK' if you are signed in as an owning user and want to create a sharing invitation.", allowCancel: true) {
                
            SyncServerUser.session.createSharingInvitation(withPermission: .admin, sharingGroupId: sharingGroupId) { (invitationUUID, error)  in
                guard error == nil else {
                    Thread.runSync(onMainThread: {
                        Alert.show(message: "Error: Could not create sharing invitation: \(error!)")
                    })
                    return
                }
                
                ViewController.sharingInvitationUUID.stringValue = invitationUUID!
                Thread.runSync(onMainThread: {
                    Alert.show(message: "You can now sign out, and sign in as a Sharing (e.g., Facebook) user.")
                })
            }
        }
    }
}

extension ViewController : GenericSignInDelegate {
    func shouldDoUserAction(signIn: GenericSignIn) -> UserActionNeeded {
        var result:UserActionNeeded = .error
        
        // A bit of a hack to test sharing users with Facebook.
        if ViewController.sharingInvitationUUID.stringValue != "" {
            result = .createSharingUser(invitationCode: ViewController.sharingInvitationUUID.stringValue)
            ViewController.sharingInvitationUUID.stringValue = ""
        } else {
            switch SignIn.userInterfaceState {
            case .createNewAccount:
                result = .createOwningUser
            
            case .existingAccount:
                result = .signInExistingUser
                
            case .initialSignInViewShowing:
                break
            }
        }
        
        return result
    }
    
    func userActionOccurred(action:UserActionOccurred, signIn: GenericSignIn) {
        switch action {
        case .userSignedOut:
            break
            
        case .userNotFoundOnSignInAttempt:
            Log.error("User not found on sign in attempt")

        case .existingUserSignedIn:
            break
            
        case .owningUserCreated:
            break
            
        case .sharingUserCreated:
            break
        }
    }
}

extension ViewController : SyncServerDelegate {    
    func syncServerFileGroupDownloadComplete(group: [DownloadOperation]) {
    }
    
    func syncServerMustResolveContentDownloadConflict(_ content: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) {
    }
    
    func syncServerMustResolveDownloadDeletionConflicts(conflicts:[DownloadDeletionConflict]) {
    }
    
    func syncServerEventOccurred(event: SyncEvent) {
        syncServerEventOccurred?(event)
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        switch error {
        case .badServerVersion(let actualServerVersion):
            let version = actualServerVersion == nil ? "nil" : actualServerVersion!.rawValue
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Bad server version", message: "actualServerVersion: \(version)")
            
        default:
            assert(false)
        }
    }
}


