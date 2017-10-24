
//
//  SignInStart.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit
import SyncServer_Shared

class SignInStart : UIView {
    @IBOutlet weak var signIn: UIButton!
    static private(set) var createOwningUser:Bool?

    override func awakeFromNib() {
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
    
    func showSignIns(`for` signInType: SignInType) {
        let signIns = SignInManager.session.getSignIns(for: signInType)
        let signInAccounts:SignInAccounts = SignInAccounts.createFromXib()!
        
        var title:SignInAccountsTitle!
        
        switch signInType {
        case SignInType.both:
            title = .existingAccount
            SignInStart.createOwningUser = false
            
        case SignInType.owningUser:
            SignInStart.createOwningUser = true
            title = .newAccount
            
        default:
            assert(false)
        }
        
        signInAccounts.changeTitle(title)
        
        signInAccounts.signIns = signIns
        superview!.addSubview(signInAccounts)
        removeFromSuperview()
    }
}
