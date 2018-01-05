//
//  HTTPURLResponseTests.swift
//  SyncServer_Tests
//
//  Created by Christopher G Prince on 1/2/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest

class HTTPURLResponseTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // I just want to make my self confident about archiving and unarchiving `HTTPURLResponse` objects.
    func testArchiving() {
        let url = URL(string: "https://www.SpasticMuffin.biz")!
        let version = "1.0"
        let headers = ["some": "header", "fields": "here"]
        let statusCode = 200
        let origResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: version, headerFields: headers)
        let data = NSKeyedArchiver.archivedData(withRootObject: origResponse as Any)
        
        guard let response = NSKeyedUnarchiver.unarchiveObject(with: data) as? HTTPURLResponse else {
            XCTFail()
            return
        }
        
        XCTAssert(response.statusCode == statusCode)
        
        for (origKey, origValue) in headers {
            guard let newValue = response.allHeaderFields[origKey] as? String, origValue == newValue else {
                XCTFail()
                return
            }
        }
        
        XCTAssert(response.url == url)
    }
}
