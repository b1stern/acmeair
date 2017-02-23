import Kitura
import Adapters
import LoggerAPI
import Entities
import SwiftyJSON

public class FlightResource: Resource {
    
    private let flightAdapter: FlightAdapter
    private let flightSegmentAdapter: FlightSegmentAdapter
    
    public init(router: Router, factory: AdapterFactory) {
        self.flightAdapter = factory.flightAdapter
        self.flightSegmentAdapter = factory.flightSegmentAdapter
        super.init()
        
        setupRoutes(router: router)
    }
    
    func setupRoutes(router: Router) {
        router.post(Resource.baseRoute + "flights/queryflights", handler: postQueryFlightsHandler)
        router.get(Resource.baseRoute + "config/countFlights", handler: countFlights)
        router.get(Resource.baseRoute + "config/countFlightSegments", handler: countFlightSegments)
        router.get(Resource.baseRoute + "config/countAirports", handler: countAirports)
        Log.info("Initialized Flights Router Service")
    }

    public func countAirports(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countAirports")
        flightSegmentAdapter.getNumberOfAirports { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    public func countFlights(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countFlights")
        flightAdapter.getNumberOfFlights { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    public func countFlightSegments(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countFlightSegments")
        flightSegmentAdapter.getNumberOfFlightSegments { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    /* Query flight information */
    func postQueryFlightsHandler(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        guard let body = request.body else {
            try response.status(.badRequest).end()
            return
        }

        guard case .urlEncoded(let params) = body else {
            try response.status(.badRequest).end()
            return
        }

        let fromAirport = params["fromAirport"] ?? ""
        let toAirport = params["toAirport"] ?? ""

        // Get flights for onward journey
        flightSegmentAdapter.getFlightSegment(originPort: fromAirport, destPort: toAirport) { resultFlightSegment in
            
            switch resultFlightSegment {

                case .success(let flightSegment):
                    if flightSegment.id == "" {
                        // NOTE: This is to comply with node implmementation and to make jmeter tests work
                        self.sendEmptyResponse(response: response, request: request, next: next)
                    } else {
                        self.getFlights(flightSegment: flightSegment, response: response, request: request, next: next)
                    }

                case .failure(_):
                    // NOTE: This is to comply with node implmementation and to make jmeter tests work
                    self.sendEmptyResponse(response: response, request: request, next: next)
            }
        }
    }

    private func getFlights(flightSegment: FlightSegment, response: RouterResponse, request: RouterRequest, next: @escaping() -> Void) {

        guard let body = request.body else {
            response.status(.badRequest)
            next()
            return
        }

        guard case .urlEncoded(let params) = body else {
            response.status(.badRequest)
            next()
            return
        }

        let fromAirport = params["fromAirport"] ?? ""
        let toAirport = params["toAirport"] ?? ""
        let fromDate = params["fromDate"]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
        let returnDate = params["returnDate"]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
        let isOneWay = params["oneWay"] ?? ""

        Log.info("postQueryFlightsHandler: Query Details FromAirport: \(fromAirport), ToAiport: \(toAirport), FromDate: \(fromDate), ToDate: \(returnDate), oneWay: \(isOneWay) \n")
        Log.info("flightSegment.id \(flightSegment.id)")

        var responseDict: [String: Any] = [:]

        self.flightAdapter.getFlights(flightSegmentId: flightSegment.id, scheduledDepartureTime: fromDate) { resultFlight in

            var flights = [Flight]()
            var flightsDict:[JSONDictionary] = [JSONDictionary]()

            switch(resultFlight) {
                case .success(let flightsRes):
                    flights = flightsRes

                case .failure(_):
                    // NOTE: This is to comply with node implmementation and to make jmeter tests work
                    self.sendEmptyResponse(response: response, request: request, next: next)
                    return
            }

            for var flight in flights {
                // TODO: Fix Workaround: Can't make flightSegment Optional since SwiftJSON doesn't handle optionals.
                flight.flightSegment = flightSegment
                flightsDict.append(flight.dict)
            }
            
            if isOneWay == "true" {
                responseDict = [
                    "tripFlights": [
                        [
                            "numPages": 1,
                            "flightsOptions": flightsDict,
                            "currentPage": 0,
                            "hasMoreOptions": false,
                            "pageSize": 10
                        ],
                    ],
                    "tripLegs": 1
                ]
                let responseJSON: JSON = JSON(responseDict)
                do {
                    response.send(json: responseJSON)
                    next()
                }
             } else {
                var flightsDictReturn:[JSONDictionary] = [JSONDictionary]()
                self.flightSegmentAdapter.getFlightSegment(originPort: toAirport, destPort: fromAirport) { resultFlightSegmentReturn in

                    var flightSegRet:FlightSegment = FlightSegment()

                    switch(resultFlightSegmentReturn) {
                        case .success(let flightSegment):
                            flightSegRet = flightSegment

                        case .failure(_):
                            // NOTE: This is to comply with node implmementation and to make jmeter tests work
                            self.sendEmptyResponse(response: response, request: request, next: next)
                            return
                    }

                    self.flightAdapter.getFlights(flightSegmentId: flightSegRet.id, scheduledDepartureTime: returnDate) { resultFlightReturn in
                        // Construct Response Object

                        var flightsRet = [Flight]()
                        switch(resultFlightReturn) {
                            case .success(let flightsRes):
                                flightsRet = flightsRes

                            case .failure(_):
                                // NOTE: This is to comply with node implmementation and to make jmeter tests work
                                self.sendEmptyResponse(response: response, request: request, next: next)
                        }

                        for var flight in flightsRet {
                            // TODO: Fix Workaround: Can't make flightSegment Optional since SwiftJSON doesn't handle optionals.
                            flight.flightSegment = flightSegRet
                            flightsDictReturn.append(flight.dict)
                        }

                        responseDict = [
                            "tripFlights": [
                                [
                                    "numPages": 1,
                                    "flightsOptions": flightsDict,
                                    "currentPage": 0,
                                    "hasMoreOptions": false,
                                    "pageSize": 10
                                ],
                                [
                                    "numPages": 1,
                                    "flightsOptions": flightsDictReturn,
                                    "currentPage": 0,
                                    "hasMoreOptions": false,
                                    "pageSize": 10
                                ]
                            ],
                            "tripLegs": 2
                        ]

                        let responseJSON: JSON = JSON(responseDict)
                        do {
                            response.send(json: responseJSON)
                            next()
                        }
                    }
                }
            }

        } // End getFlights
    }

    private func sendEmptyResponse(response: RouterResponse, request: RouterRequest, next: @escaping() -> Void) {
        let flightsDict:[JSONDictionary] = [JSONDictionary]()
        var responseDict: [String: Any] = [:]

        responseDict = [
            "tripFlights": [
                [
                    "numPages": 1,
                    "flightsOptions": flightsDict,
                    "currentPage": 0,
                    "hasMoreOptions": false,
                    "pageSize": 10
                ],
            ],
            "tripLegs": 1
        ]
        let responseJSON: JSON = JSON(responseDict)
        do {
            response.send(json: responseJSON)
            next()
        }
    }
}
