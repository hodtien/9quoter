import Foundation
import Testing
@testable import _QuoterApp

struct BasicAuthCredentialsTests {
    @Test("Builds Basic Auth header from username and password")
    func buildsBasicAuthHeader() {
        let credentials = BasicAuthCredentials(username: "karl", password: "secret")

        #expect(credentials.authorizationHeader == "Basic a2FybDpzZWNyZXQ=")
    }

    @Test("Does not build Basic Auth header when username is empty")
    func skipsHeaderWhenUsernameIsEmpty() {
        let credentials = BasicAuthCredentials(username: "  ", password: "secret")

        #expect(credentials.authorizationHeader == nil)
    }

    @Test("Does not build Basic Auth header when password is empty")
    func skipsHeaderWhenPasswordIsEmpty() {
        let credentials = BasicAuthCredentials(username: "karl", password: "")

        #expect(credentials.authorizationHeader == nil)
    }

    @Test("Trims surrounding username whitespace before encoding")
    func trimsUsernameBeforeEncoding() {
        let credentials = BasicAuthCredentials(username: "  karl  ", password: "secret")

        #expect(credentials.authorizationHeader == "Basic a2FybDpzZWNyZXQ=")
    }
}
