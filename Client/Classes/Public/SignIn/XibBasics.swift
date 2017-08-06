//
//  XibBasics.swift
//  SyncServer
//
//  Created by Christopher G Prince on 7/31/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol XibBasics {
    associatedtype ViewType
}

extension XibBasics {
    public static func create() -> ViewType? {
        let bundle = Bundle(for: SignInManager.self)
        guard let viewType = bundle.loadNibNamed(typeName(self), owner: self, options: nil)?[0] as? ViewType else {
            assert(false)
            return nil
        }
        
        return viewType
    }
}
