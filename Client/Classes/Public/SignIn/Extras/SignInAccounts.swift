
//
//  SignInAccounts.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit

enum SignInAccountsTitle : String {
    case existingAccount = "Existing Account"
    case newAccount = "New Account"
    case signedIn = "Signed In"
}


private class SignInButtonCell : UITableViewCell {
    var signInButton:UIView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        signInButton?.removeFromSuperview()
        signInButton = nil
    }
}

class SignInAccounts : UIView {
    @IBOutlet weak var tableView: UITableView!
    var signIns:[GenericSignIn]!
    let reuseIdentifier = "SignInAccountsCell"
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var title: UILabel!
    
    func changeTitle(_ title: SignInAccountsTitle) {
        self.title.text = title.rawValue
        self.title.sizeToFit()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.register(SignInButtonCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        _ = SignInManager.session.signInStateChanged.addTarget!(self, with: #selector(signInStateChanged))
        
        setup()
    }
    
    deinit {
        SignInManager.session.signInStateChanged.removeTarget!(self, with: #selector(signInStateChanged))
    }
    
    func setup() {
        // Hiding the back button when a user is signed in because the only action we want to allow is signing out in this case. If no user is signed, then user should be able to go back, and create a new user (not sign-in) if they want.
        backButton.isHidden = SignInManager.session.userIsSignIn
    }
    
    func signInStateChanged() {
        if SignInManager.session.userIsSignIn {
            changeTitle(.signedIn)
        }
        else {
            signIns = SignInManager.session.getSignIns(for: .both)
            changeTitle(.existingAccount)
        }
        
        tableView.reloadData()
        setup()
    }
    
    @IBAction func backAction(_ sender: Any) {
        superview!.addSubview(SignInStart.createFromXib()!)
        removeFromSuperview()
    }
    
    func currentSignIns() -> [GenericSignIn] {
        if SignInManager.session.userIsSignIn {
            changeTitle(.signedIn)

            // If user is signed in, only want to present that sign-in button, to allow them to sign out.
            return signIns.filter({$0.userIsSignedIn})
        }
        else {
            // If user is not signed in, show them the full set of possibilities. 
            return signIns
        }
    }
}

extension SignInAccounts : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSignIns().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! SignInButtonCell
        let signInButton = currentSignIns()[indexPath.row].signInButton!
        
        // Get some oddness with origins being negative.
        signInButton.frameOrigin = CGPoint.zero
        
        cell.signInButton = signInButton
        cell.contentView.addSubview(signInButton)
        
        signInButton.centerInSuperview()
        
        cell.backgroundColor = UIColor.clear
        cell.contentView.backgroundColor = UIColor.clear

        return cell
    }
}
