import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

// After creating this project afresh, I was getting errors like: "...couldn’t be loaded because it is damaged or missing necessary resources. Try reinstalling the bundle."
// The solution for me was to manually set the host applicaton. See https://github.com/CocoaPods/CocoaPods/issues/5022

class TestCreds : GenericCredentials {
    var userId = ""
    var username = ""
    var uiDisplayName = ""
    var httpRequestHeaders:[String:String] {
        return [String:String]()
    }
    
    var called = false
    func refreshCredentials(completion: @escaping (SyncServerError?) ->()) {
        called = true
        completion(.credentialsRefreshError)
    }
}

class ServerAPI_Authentication: TestCase {
    override func setUp() {
        super.setUp()
        if currTestAccountIsSharing() {
            return
        }
        
        Log.msg("deviceUUID1: \(self.deviceUUID)")

        let exp = expectation(description: "\(#function)\(#line)")

        // Remove the user in case they already exist-- e.g., from a previous test.
        ServerAPI.session.removeUser(retryIfError: false) { error in
            // There will be an error here if the user didn't exist already.
            exp.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAddUserWithoutAuthenticationDelegateFails() {
        if currTestAccountIsSharing() {
            return
        }
        
        let expectation = self.expectation(description: "authentication")
        ServerNetworking.session.delegate = nil
        
        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error != nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func testAddUserWithAuthenticationDelegateWorks() {
        if currTestAccountIsSharing() {
            return
        }
        
        let expectation = self.expectation(description: "authentication")
        
        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error == nil)
            XCTAssert(userId != nil)
            XCTAssert(sharingGroupId != nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCheckCredsWithValidUserCredsWorks() {
        if currTestAccountIsSharing() {
            return
        }
        
        let expectation = self.expectation(description: "authentication")
        let addUserExpectation = self.expectation(description: "addUser")

        Log.msg("deviceUUID1: \(self.deviceUUID)")

        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error == nil)
            XCTAssert(userId != nil)
            XCTAssert(sharingGroupId != nil)
            addUserExpectation.fulfill()
            ServerAPI.session.checkCreds { checkCredsResult, error in
                XCTAssert(error == nil)
                guard case .user = checkCredsResult! else {
                    XCTFail()
                    return
                }
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCheckCredsWithBadAuthenticationValuesFail() {
        if currTestAccountIsSharing() {
            return
        }
        
        let addUserExpectation = self.expectation(description: "addUser")
        let expectation = self.expectation(description: "authentication")
        
        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error == nil)
            XCTAssert(userId != nil)
            XCTAssert(sharingGroupId != nil)
            addUserExpectation.fulfill()
            
            self.authTokens[ServerConstants.HTTPOAuth2AccessTokenKey] = "foobar"
            
            ServerAPI.session.checkCreds { checkCredsResult, error in
                XCTAssert(error == nil)
                guard case .noUser = checkCredsResult! else {
                    XCTFail()
                    return
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testRemoveUserWithBadAccessTokenFails() {
        if currTestAccountIsSharing() {
            return
        }
        
        let addUserExpectation = self.expectation(description: "addUser")
        let removeUserExpectation = self.expectation(description: "removeUser")
        
        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error == nil)
            XCTAssert(userId != nil)
            XCTAssert(sharingGroupId != nil)
            addUserExpectation.fulfill()
            
            self.authTokens[ServerConstants.HTTPOAuth2AccessTokenKey] = "foobar"
            
            ServerAPI.session.removeUser { error in
                // Expect an error here because we have a bad access token.
                XCTAssert(error != nil)
                removeUserExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func testRemoveUserSucceeds() {
        if currTestAccountIsSharing() {
            return
        }
        
        let addUserExpectation = self.expectation(description: "addUser")
        let removeUserExpectation = self.expectation(description: "removeUser")
        let addUserExpectation2 = self.expectation(description: "addUser2")

        ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
            XCTAssert(error == nil)
            XCTAssert(userId != nil)
            XCTAssert(sharingGroupId != nil)
            addUserExpectation.fulfill()
            
            ServerAPI.session.removeUser { error in
                XCTAssert(error == nil)
                removeUserExpectation.fulfill()
                
                // Because we don't want to leave tests in a state where we don't have the user we need.
                ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
                    XCTAssert(error == nil)
                    XCTAssert(userId != nil)
                    XCTAssert(sharingGroupId != nil)
                    addUserExpectation2.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCredentialsRefreshGenerically() {
        guard let sharingGroupId = getFirstSharingGroupId() else {
            XCTFail()
            return
        }
        
        let testCreds = TestCreds()
        testCreds.uiDisplayName = "chris@cprince.com"
        testCreds.username = "Chris"
        
        ServerAPI.session.creds = testCreds
        let previousAuthTokens = authTokens
        authTokens = [:]
        
        // Just do a (random) server call on the API to make use of the creds, and ensure the ServerAPI attempts a credentials refresh.
        
        let expectation1 = self.expectation(description: "fileIndex")
        
        ServerAPI.session.fileIndex(sharingGroupId: sharingGroupId) { (fileIndex, masterVersion, error) in
            XCTAssert(error != nil)
            XCTAssert(testCreds.called == true)
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: 60.0, handler: nil)
        
        if !currTestAccountIsSharing() {
            authTokens = previousAuthTokens
            
            let addUserExpectation = self.expectation(description: "addUser")
            
            ServerAPI.session.addUser(cloudFolderName: self.cloudFolderName) { userId, sharingGroupId, error in
                XCTAssert(error == nil)
                XCTAssert(userId != nil)
                addUserExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 10.0, handler: nil)
        }
    }
}
