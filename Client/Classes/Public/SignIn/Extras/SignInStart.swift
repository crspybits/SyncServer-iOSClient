
//
//  SignInStart.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit
import SyncServer_Shared

public class SignInStart : UIView {
    @IBOutlet weak var signIn: UIButton!
    static private(set) var createOwningUser:Bool?

    public override func awakeFromNib() {
        super.awakeFromNib()
        signIn.titleLabel?.textAlignment = .center
        
        if SignInManager.session.userIsSignedIn {
            showSignIns(for: .both)
        }
        
        _ = SignInManager.session.signInStateChanged.addTarget!(self, with: #selector(signInStateChanged))
        
        SignInStart.createOwningUser = nil
    }
    
    deinit {
        SignInManager.session.signInStateChanged.removeTarget!(self, with: #selector(signInStateChanged))
    }
    
    func signInStateChanged() {
        // If displayed
        if superview != nil {
            if SignInManager.session.userIsSignedIn {
                showSignIns(for: .both)
            }
        }
    }
    
    @IBAction func signInAction(_ sender: Any) {
        showSignIns(for: .both)
    }
    
    @IBAction func createNewAccountAction(_ sender: Any) {
        showSignIns(for: .owningUser)
    }
    
    public func showSignIns(`for` signInType: SignInType) {
        let signIns = SignInManager.session.getSignIns(for: signInType)
        let signInAccounts:SignInAccounts = SignInAccounts.createFromXib()!
        
        var title:SignInAccountsTitle!
        
        switch signInType {
        case .both:
            title = .existingAccount
            SignInStart.createOwningUser = false
            
        case .owningUser:
            SignInStart.createOwningUser = true
            title = .newAccount
            
        case .sharingUser:
            SignInStart.createOwningUser = false
            title = .sharingAccount
            
        default:
            // It's odd that this is needed. `SignInType` only has three possible values.
            assert(false)
        }
        
        signInAccounts.changeTitle(title)
        
        signInAccounts.signIns = signIns
        
        // 10/1/17; Getting a crash right here-- after I have an error creating a sharing account with Facebook. I think there is no superview.
        superview!.addSubview(signInAccounts)
        
        removeFromSuperview()
    }
}
