import XCTest
import TitanSwiftHTTPAdapter
import HTTP
import TitanCore

final class TitanSwiftHTTPAdapterTests: XCTestCase {
    
    var titanInstance: Titan!
    var port: UInt32!
    var server: HTTPServer!
    
    override func setUp() {
        port = 12345
        titanInstance = Titan()
        // Configure Swift HTTP server
        let httpHandler = httpRequestHandlerFromTitanApp(titanInstance.app)
        server = HTTPServer()
        
        
        do {
            try server.start(port: Int(port), handler: httpHandler)
        } catch {
            XCTFail("Can't listen")
        }
    }
    
    override func tearDown() {
        server.stop()
        server = nil
    }
    
    func testConvertingSwiftHTTPRequestToTitanRequest() {
        let body = "Some body goes here"
        let length = "\(body.utf8.count)"
        let session = URLSession(configuration: .default)
        
        let requestExp = expectation(description: "requestReceived")
        var titanRequestConvertedFromKitura: TitanCore.RequestType!
        titanInstance.addFunction { (request, response) -> (TitanCore.RequestType, TitanCore.ResponseType) in
            titanRequestConvertedFromKitura = request
            requestExp.fulfill()
            return (request, response)
        }
        
        // Make the request
        
        guard let url = URL(string: "http://localhost:\(port!)/complexPath/with/comps?query=string&value=stuff") else {
            XCTFail("Can't create URL")
            return
        }
        var r = URLRequest(url: url)
        r.httpMethod = "PATCH"
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(length, forHTTPHeaderField: "Content-Length")
        r.httpBody = body.data(using: .utf8)
        
        session.dataTask(with: r).resume()
        
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertNotNil(titanRequestConvertedFromKitura)
        XCTAssertEqual(titanRequestConvertedFromKitura.path, "/complexPath/with/comps?query=string&value=stuff")
        XCTAssertEqual(titanRequestConvertedFromKitura.bodyString, "Some body goes here")
        XCTAssertEqual(titanRequestConvertedFromKitura.method, "PATCH")
        var headerPair: Header? = nil
        for (key, value) in titanRequestConvertedFromKitura.headers {
            if key == "Accept" && value == "application/json" {
                headerPair = (key, value)
                break
            }
        }
        XCTAssertNotNil(headerPair)
    }
    
    func testConvertingTitanResponseToSwiftHTTPResponse() throws {
        let titanResponse = try TitanCore.Response(code: 501, body: "Not implemented; developer is exceedingly lazy",
                                                   headers: [("Cache-Control", "private")])
        
        titanInstance.addFunction { (request, _) -> (TitanCore.RequestType, TitanCore.ResponseType) in
            return (request, titanResponse)
        }
        
        let session = URLSession(configuration: .default)
        var data: Data!, resp: HTTPURLResponse!, err: Swift.Error!
        let x = expectation(description: "Response received")
        session.dataTask(with: URL(string: "http://localhost:\(port!)/")!) { (d, r, e) in
            data = d
            resp = r as? HTTPURLResponse
            err = e
            x.fulfill()
            }.resume()
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNil(err)
        XCTAssertNotNil(data)
        XCTAssertNotNil(resp)
        
        XCTAssertEqual(resp.statusCode, 501)
        XCTAssertEqual(resp.allHeaderFields["Cache-Control"] as? String, "private")
        XCTAssertEqual(data, "Not implemented; developer is exceedingly lazy".data(using: .utf8)!)
    }
    
    static var allTests: [(String, (TitanSwiftHTTPAdapterTests) -> () throws -> Void)] {
        return [
            ("testConvertingSwiftHTTPRequestToTitanRequest", testConvertingSwiftHTTPRequestToTitanRequest),
            ("testConvertingTitanResponseToSwiftHTTPResponse", testConvertingTitanResponseToSwiftHTTPResponse)
        ]
    }
}
