//
//  HashingTests.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 10/21/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer

class HashingTests: XCTestCase {
    var testURL: URL!
    
    override func setUp() {
        testURL = Bundle.main.url(forResource: "milky-way-nasa", withExtension: "jpg")
        if testURL == nil {
            XCTFail("Could not get url for example file!")
        }
    }

    override func tearDown() {
    }

    func testDropbox() {
        let hash = Hashing.generateDropbox(fromLocalFile: testURL)
        XCTAssert(hash == "485291fa0ee50c016982abbfa943957bcd231aae0492ccbaa22c58e3997b35e0")
    }
    
    func testGoogle() {
        let md5Hash = Hashing.generateMD5(fromURL: testURL)
        
        // I used http://onlinemd5.com to generate the MD5 hash from the image.
        XCTAssert(md5Hash == "F83992DC65261B1BA2E7703A89407E6E".lowercased())
    }
}
