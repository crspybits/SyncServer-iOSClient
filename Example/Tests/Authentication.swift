import XCTest
@testable import SyncServer
import SMCoreLib
import SyncServer_Shared

// After creating this project afresh, I was getting errors like: "...couldn’t be loaded because it is damaged or missing necessary resources. Try reinstalling the bundle."
// The solution for me was to manually set the host applicaton. See https://github.com/CocoaPods/CocoaPods/issues/5022

enum TestCredsError : Error {
    case TheError
}

class TestCreds : GenericCredentials {
    var userId = ""
    var username = ""
    var uiDisplayName = ""
    var httpRequestHeaders:[String:String] {
        return [String:String]()
    }
    
    var called = false
    func refreshCredentials(completion: @escaping (Error?) ->()) {
        called = true
        completion(TestCredsError.TheError)
    }
}

class ServerAPI_Authentication: TestCase {
    override func setUp() {
        super.setUp()
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
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAddUserWithoutAuthenticationDelegateFails() {
        let expectation = self.expectation(description: "authentication")
        ServerNetworking.session.authenticationDelegate = nil
        
        ServerAPI.session.addUser { error in
            XCTAssert(error != nil) 
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 40.0, handler: nil)
    }
    
    func testAddUserWithAuthenticationDelegateWorks() {
        let expectation = self.expectation(description: "authentication")
        
        ServerAPI.session.addUser { error in
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCheckCredsWithValidUserCredsWorks() {
        let expectation = self.expectation(description: "authentication")
        let addUserExpectation = self.expectation(description: "addUser")

        Log.msg("deviceUUID1: \(self.deviceUUID)")

        ServerAPI.session.addUser { error in
            XCTAssert(error == nil)
            addUserExpectation.fulfill()
            ServerAPI.session.checkCreds { checkCredsResult, error in
                XCTAssert(error == nil)
                guard case .owningUser = checkCredsResult! else {
                    XCTFail()
                    return
                }
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCheckCredsWithBadAuthenticationValuesFail() {
        let addUserExpectation = self.expectation(description: "addUser")
        let expectation = self.expectation(description: "authentication")
        
        ServerAPI.session.addUser { error in
            XCTAssert(error == nil)
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
        let addUserExpectation = self.expectation(description: "addUser")
        let removeUserExpectation = self.expectation(description: "removeUser")
        
        ServerAPI.session.addUser { error in
            XCTAssert(error == nil)
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
        let addUserExpectation = self.expectation(description: "addUser")
        let removeUserExpectation = self.expectation(description: "removeUser")
        
        ServerAPI.session.addUser { error in
            XCTAssert(error == nil)
            addUserExpectation.fulfill()
            
            ServerAPI.session.removeUser { error in
                XCTAssert(error == nil)
                removeUserExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testCredentialsRefreshGenerically() {
        let testCreds = TestCreds()
        testCreds.uiDisplayName = "chris@cprince.com"
        testCreds.username = "Chris"
        ServerAPI.session.creds = testCreds
        
        // Just do a (random) server call on the API to make use of the creds, and ensure the ServerAPI attempts a credentials refresh.
        
        let expectation1 = self.expectation(description: "fileIndex")
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            XCTAssert(error != nil)
            XCTAssert(testCreds.called == true)
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 60.0, handler: nil)
    }
}