//
//  ServerVersion.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 2/1/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerVersionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLessThanWorks() {
        let dataset:[(v1: String, v2:String, result: Bool)] = [
            (v1: "0.0.0", v2:"0.0.0", result: false),
            (v1: "0.0.1", v2:"0.0.0", result: false),
            (v1: "0.1.0", v2:"0.0.0", result: false),
            (v1: "1.0.0", v2:"0.0.0", result: false),
            (v1: "0.0.0", v2:"0.0.1", result: true),
            (v1: "0.0.0", v2:"0.1.0", result: true),
            (v1: "0.0.0", v2:"1.0.0", result: true),
            (v1: "0.1.2", v2:"1.0.0", result: true),
        ]
        
        for data in dataset {
            guard let v1 = ServerVersion(rawValue: data.v1),
                let v2 = ServerVersion(rawValue: data.v2) else {
                XCTFail()
                return
            }
            
            XCTAssert((v1 < v2) == data.result)
        }
    }
}
