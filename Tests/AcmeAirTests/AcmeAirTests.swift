import XCTest
import Foundation
import Dispatch
import LoggerAPI
import HeliumLogger
import MongodbAdapters
import KituraNet
import SwiftyJSON
@testable import Loader
@testable import AcmeAir

let dbHost = ProcessInfo.processInfo.environment["DB_HOST"] ?? "localhost"
let dbPort = ProcessInfo.processInfo.environment["DB_PORT"] ?? "27017"
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8090") ?? 8090

class AcmeAirTests: XCTestCase {
    
    let defaultUser = "uid1@email.com"
    
    var acmeairServer: AcmeAir? = nil

    static var allTests : [(String, (AcmeAirTests) -> () throws -> Void)] {
        return [
            ("testPing", testPing),
            ("testBookingProcess", testBookingProcess),
            ("testCustomerUpdate", testCustomerUpdate),
            ("testGetCustomer", testGetCustomer),
            ("testFlightQuery", testFlightQuery),
            ("testCustomerSession", testCustomerSession),
            ("testDataLoader", testDataLoader)
        ]
    }
    
    override func setUp() {
        super.setUp()

        HeliumLogger.use(.debug)
        
        do {
            if let mongodbAdapterFactory = try MongodbAdapterFactory.createFactory(properties: ["dbName": "acmeair", "host": dbHost, "port": dbPort], configurationPath: nil) {
            
                acmeairServer = AcmeAir(port: serverPort, factory: mongodbAdapterFactory)
                if acmeairServer == nil {
                    XCTFail("The server is nil")
                    return
                }
                self.acmeairServer!.start()
                
                let loader = try MongoDBLoader()
                try loader.dropDatabase()
                try loader.loadDatabase()

            } else {
                XCTFail("Unable to start Acmeair")
            }
        } catch {
            XCTFail()
        }
        
    }
    
    override func tearDown() {
        super.tearDown()
        acmeairServer!.stop()
    }
    
    func testPing() {
        
        let pingExpectation = expectation(description: "Quick status check for server.")
        
        URLRequest(forTestWithMethod: "GET", route: "rest/api/checkstatus")
            .sendForTestingWithKitura { resp, data in
                XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                XCTAssertEqual(resp.statusCode.rawValue, 200)
                XCTAssertEqual(data.count, 0)
                pingExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
    }
    
    func testBookingProcess() {
        
        let bookingExpectation = expectation(description: "Get a flight booking for a user (then delete it)")
        
        guard let flightData = "userid=\(defaultUser)&toFlightId=AA0&retFlightId=AA2&oneWayFlight=false".data(using: String.Encoding.utf8) else {
            XCTFail("Failed to create data object from flight data.")
            return
        }
        
        URLRequest(forTestWithMethod: "POST", route: "rest/api/bookings/bookflights",
                   contentType: "application/x-www-form-urlencoded", body: flightData)
            .sendForTestingWithKitura { resp, data in
                XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                XCTAssertEqual(resp.statusCode.rawValue, 200)
        
     
            URLRequest(forTestWithMethod: "GET", route: "rest/api/bookings/byuser/\(self.defaultUser)")
            .sendForTestingWithKitura { resp, data in
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let booking = jsonArray.filter { ($0["flightId"] as? String) ?? "" == "AA0" }
                        XCTAssertGreaterThan(booking.count, 0)
                        
                        if let firstBooking = booking.first, let bookingId = firstBooking["_id"] as? String,
                           let bodyData = "number=\(bookingId)&userid=\(self.defaultUser)".data(using: String.Encoding.utf8) {
                            
                            // Test cancelling a booking
                            XCTAssertEqual(firstBooking["customerId"] as? String, self.defaultUser)
                            URLRequest(forTestWithMethod: "POST", route: "rest/api/bookings/cancelbooking",
                                       contentType: "application/x-www-form-urlencoded", body: bodyData)
                                .sendForTestingWithKitura { resp, data in
                                    let jsonData = JSON(data: data)
                                    XCTAssertEqual(jsonData["status"].stringValue, "success")
                                    bookingExpectation.fulfill()
                            }
                        }
                        
                    }
                } catch {
                    XCTFail("Failed to convert data to Json")
                }
            }
        }

        waitForExpectations(timeout: 20.0, handler: nil)
    }
    
    /* Customer Tests */
    
    func testCustomerUpdate() {
        
        let customerExpectation = expectation(description: "Create a customer and get that customer.")
        
        let addressJson = ["streetAddress1": "1234 Main St.", "streetAddress2": "Apt 111", "city": "Round Rock",
                           "stateProvince": "TX", "country": "USA", "postalCode": "78787"]
        let customerJson = JSON(["password": "password", "status": "GOLD", "total_miles": 10000,
                                 "miles_ytd": 1000, "phoneNumber": "512-555-5555", "phoneNumberType": "HOME", "address": addressJson])
        do {
            URLRequest(forTestWithMethod: "POST", route: "rest/api/customer/byid/\(defaultUser)",
                       contentType: "application/json", body: try customerJson.rawData())
                .sendForTestingWithKitura { resp, data in
                    XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                    XCTAssertEqual(resp.statusCode.rawValue, 200)
                    
                    let customer = JSON(data: data)
                    XCTAssertEqual(customer["password"].string, customerJson["password"].string)
                    XCTAssertEqual(customer["status"].string, customerJson["status"].string)
                    XCTAssertEqual(customer["total_miles"].int, customerJson["total_miles"].int)
                    XCTAssertEqual(customer["miles_ytd"].int, customerJson["miles_ytd"].int)
                    XCTAssertEqual(customer["phoneNumber"].string, customerJson["phoneNumber"].string)
                    XCTAssertEqual(customer["phoneNumberType"].string, customerJson["phoneNumberType"].string)
                    XCTAssertEqual(customer["address"]["streetAddress1"].string, addressJson["streetAddress1"])
                    XCTAssertEqual(customer["address"]["city"].string, addressJson["city"])
                    XCTAssertEqual(customer["address"]["stateProvince"].string, addressJson["stateProvince"])
                    XCTAssertEqual(customer["address"]["country"].string, addressJson["country"])
                    XCTAssertEqual(customer["address"]["postalCode"].string, addressJson["postalCode"])
                    
                    customerExpectation.fulfill()
            }
        } catch {
            XCTFail("Failed to convert JSON to Data")
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
    }
    
    func testGetCustomer() {
        
        let customerExpectation = expectation(description: "Gets a customer's data.")
        
        URLRequest(forTestWithMethod: "GET", route: "rest/api/customer/byid/\(defaultUser)")
            .sendForTestingWithKitura { resp, data in
                XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                XCTAssertEqual(resp.statusCode.rawValue, 200)
                
                let customer = JSON(data: data)
                // verify a few values
                XCTAssertEqual(customer["_id"].stringValue, self.defaultUser)
                XCTAssertNotNil(customer["total_miles"].int)
                XCTAssertNotNil(customer["address"].dictionary)
                
                customerExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
    }
    
    /* Flight tests */
    
    func testFlightQuery() {
        
        let flightExpectation = expectation(description: "Gets info for a flight.")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E MMM dd 00:00:00 z yyyy"
        let dateString = dateFormatter.string(from: Date())
        let encodedDate = dateString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)

        guard let date = encodedDate,
              let flightData = "fromAirport=FRA&toAirport=FCO&fromDate=\(date)&returnDate=\(date)&oneWay=false".data(using: String.Encoding.utf8) else {
            XCTFail("Failed to create data object from flight data.")
            return
        }
        
        URLRequest(forTestWithMethod: "POST", route: "rest/api/flights/queryflights",
                   contentType: "application/x-www-form-urlencoded", body: flightData)
            .sendForTestingWithKitura { resp, data in
                XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                XCTAssertEqual(resp.statusCode.rawValue, 200)
                
                let flightJson = JSON(data: data)
                let tripFlights = flightJson["tripFlights"].arrayValue
                print("JJJ: \(flightJson.description)")
                XCTAssertGreaterThan(tripFlights.count, 1)
                for json in tripFlights {
                    XCTAssertGreaterThan(json["flightsOptions"].arrayValue.count, 0)
                }
                
                flightExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
    }
    
    func testCustomerSession() {
        
        let sessionExpectation = expectation(description: "Logs in a customer and then logs them out")
        
        guard let customerData = "login=\(defaultUser)&password=password".data(using: String.Encoding.utf8) else {
            XCTFail("Failed to create data object from customer login data.")
            return
        }
        
        URLRequest(forTestWithMethod: "POST", route: "rest/api/login",
                   contentType: "application/x-www-form-urlencoded", body: customerData)
            .sendForTestingWithKitura { resp, data in
                XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                XCTAssertEqual(resp.statusCode.rawValue, 200)
                
                let loginResponse = String(data: data, encoding: String.Encoding.utf8)
                XCTAssertEqual(loginResponse, "logged in")
                
                URLRequest(forTestWithMethod: "GET", route: "rest/api/login/logout?login=\(self.defaultUser)")
                    .sendForTestingWithKitura { resp, data in
                        XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                        XCTAssertEqual(resp.statusCode.rawValue, 200)
                
                        let logoutResponse = String(data: data, encoding: String.Encoding.utf8)
                        XCTAssertEqual(logoutResponse, "logged out")
                        
                        sessionExpectation.fulfill()
                }
                
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
    }
    
    func testDataLoader() throws {
        
        let dbLoaderExpectation = expectation(description: "Loads data into database.")
        
        if let loader = try? MongoDBLoader() {
        
            try loader.dropDatabase()
            URLRequest(forTestWithMethod: "GET", route: "rest/api/loader/load?numCustomers=947")
                .sendForTestingWithKitura { resp, data in
                    XCTAssertNotEqual(resp.statusCode.rawValue, 404)
                    XCTAssertEqual(resp.statusCode.rawValue, 200)
                    
                    let loadResponse = String(data: data, encoding: String.Encoding.utf8)
                    XCTAssertNotNil(loadResponse)
                    XCTAssertEqual(loadResponse!, "Database Finished Loading")
                    
                    do {
                        let flightSegmentCount = try loader.database["flightSegment"].count()
                        XCTAssertEqual(flightSegmentCount, 394)
                        XCTAssertEqual(try loader.database["flight"].count(), 1970)
                        XCTAssertEqual(try loader.database["customer"].count(), 947)
                        XCTAssertEqual(try loader.database["airportCodeMapping"].count(), 14)
                    } catch {
                        XCTFail("Could not load database")
                    }
                    
                    dbLoaderExpectation.fulfill()
            }
        } else {
            XCTFail("Failed to drop database.")
        }
        
        waitForExpectations(timeout: 20.0, handler: nil)
        
    }
    
}

private extension URLRequest {
    
    init(forTestWithMethod method: String, route: String = "", contentType: String? = nil, authToken: String? = nil, body: Data? = nil) {
        let url = URL(string: "http://127.0.0.1:\(serverPort)/" + route)
        XCTAssertNotNil(url, "URL is nil, the following route may be invalid: \(route)")
        self.init(url: url!)
        if let contentType = contentType {
            addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let authToken = authToken {
            addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        httpMethod = method
        cachePolicy = .reloadIgnoringCacheData
        if let body = body {
            httpBody = body
        }
    }
    
    func sendForTestingWithKitura(fn: @escaping (ClientResponse, Data) -> Void) {
        
        guard let method = httpMethod, var path = url?.path else {
            XCTFail("Invalid request params")
            return
        }
        
        if let query = url?.query {
            path += "?" + query
        }
        
        var requestOptions: [ClientRequest.Options] = [.method(method), .hostname("localhost"), .port(8090), .path(path)]
        if let headers = allHTTPHeaderFields {
            requestOptions.append(.headers(headers))
        }
        
        let req = HTTP.request(requestOptions) { resp in
            
            if let resp = resp, resp.statusCode == HTTPStatusCode.OK || resp.statusCode == HTTPStatusCode.accepted {
                do {
                    var body = Data()
                    try resp.readAllData(into: &body)
                    fn(resp, body)
                } catch {
                    print("Bad JSON document received from AcmeAir-Server.")
                }
            } else {
                if let resp = resp {
                    print("Status code: \(resp.statusCode)")
                    var rawUserData = Data()
                    do {
                        let _ = try resp.read(into: &rawUserData)
                        let str = String(data: rawUserData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                        print("Error response from AcmeAir-Server: \(String(describing: str))")
                    } catch {
                        print("Failed to read response data.")
                    }
                }
            }
        }
        if let dataBody = httpBody {
            req.end(dataBody)
        } else {
            req.end()
        }
        
    }

}
