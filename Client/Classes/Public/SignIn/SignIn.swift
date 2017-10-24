
//
//  SignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit

public class SignIn : UIView {
    public var signInStart:SignInStart!
    
    public enum SignInUIState {
        // asking if user wants to sign-in as existing or new user
        case initialSignInViewShowing
        
        // view showing allows user to create a new (owning) user
        case createNewAccount
        
        // view allowing user to sign in as existing user
        case existingAccount
    }

    public static var userInterfaceState:SignInUIState {
        switch SignInStart.createOwningUser {
        case .none:
            return .initialSignInViewShowing
            
        case .some(true):
            return .createNewAccount
            
        case .some(false):
            return .existingAccount
        }
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        signInStart = SignInStart.createFromXib()!
        addSubview(signInStart)
    }
}
