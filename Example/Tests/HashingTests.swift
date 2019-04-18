//
//  HashingTests.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 10/21/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib
import FileMD5Hash

class HashingTests: XCTestCase {
    var testURL: URL!
    
    override func setUp() {
        testURL = Bundle.main.url(forResource: "milky-way-nasa", withExtension: "jpg")
        //testURL = Bundle.main.url(forResource: "Cat", withExtension: "jpg")
        if testURL == nil {
            XCTFail("Could not get url for example file!")
        }
    }

    override func tearDown() {
    }

    func testDropboxFromURL() {
        let hash = Hashing.generateDropbox(fromLocalFile: testURL)
        // print("hash: \(hash)")
        XCTAssert(hash == "485291fa0ee50c016982abbfa943957bcd231aae0492ccbaa22c58e3997b35e0")
    }
    
    // The purpose of this test is mostly to bootstrap a hash value to use in server tests.
    func testDropboxFromURL2() {
        guard let url = Bundle.main.url(forResource: "example", withExtension: "url") else {
            XCTFail()
            return
        }

        let hash = Hashing.generateDropbox(fromLocalFile: url)
        // print("hash: \(hash)")
        XCTAssert(hash == "842520e78cc66fad4ea3c5f24ad11734075d97d686ca10b799e726950ad065e7")
    }
    
    func testDropboxFromData() {
        guard let data = "This is some longer text that I'm typing here and hopefullly I don't get too bored".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        guard let hash = Hashing.generateDropbox(fromData: data) else {
            XCTFail()
            return
        }
        
        print("hash: \(hash)")
    }
    
    func testGoogleFromURL() {
        guard let md5Hash = Hashing.generateMD5(fromURL: testURL) else {
            XCTFail()
            return
        }
        
        print("md5Hash: \(md5Hash)")
        // I used http://onlinemd5.com to generate the MD5 hash from the image.
        XCTAssert(md5Hash == "F83992DC65261B1BA2E7703A89407E6E".lowercased())
    }
    
    // The purpose of this test is mostly to bootstrap a hash value to use in server tests.
    func testGoogleFromURL2() {
        guard let url = Bundle.main.url(forResource: "example", withExtension: "url") else {
            XCTFail()
            return
        }

        guard let md5Hash = Hashing.generateMD5(fromURL: url) else {
            XCTFail()
            return
        }
        
        print("md5Hash: \(md5Hash)")
        XCTAssert(md5Hash == "958c458be74acfcf327619387a8a82c4")
    }
    
    func testGoogleFromData() {
        guard let data = "Hello World".data(using: .utf8) else {
            XCTFail()
            return
        }
        
        guard let md5Hash = Hashing.generateMD5(fromData: data) else {
            XCTFail()
            return
        }
        
        print("md5Hash: \(md5Hash)")
    }
    
    func testGoogleFromData2() {
        guard let data = try? Data(contentsOf: testURL) else {
            XCTFail()
            return
        }
        
        guard let md5Hash = Hashing.generateMD5(fromData: data) else {
            XCTFail()
            return
        }
        
        print("md5Hash: \(md5Hash)")
    }
    
    func testFileMD5Hash() {
        guard let md5Hash = FileHash.md5HashOfFile(atPath: testURL.path) else {
            XCTFail()
            return
        }
        print("md5Hash: \(md5Hash)")
    }
}
