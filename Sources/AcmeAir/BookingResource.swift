import Kitura
import Adapters
import LoggerAPI
import Entities
import SwiftyJSON
import Foundation


public class BookingResource: Resource {
    let adapterFactory: AdapterFactory
    
    public init(router: Router, factory: AdapterFactory) {
        self.adapterFactory = factory
        super.init()
        
        setupRoutes(router: router)
    }
    
    func setupRoutes(router: Router) {
        router.post(Resource.baseRoute + "bookings/bookflights", handler: createBooking)
        router.post(Resource.baseRoute + "bookings/cancelbooking", handler: cancelBooking)
        router.get(Resource.baseRoute + "bookings/byuser/:userid", handler: getBooking)
        router.get(Resource.baseRoute + "config/countBookings", handler: countBookings)
        Log.info("Initialized Booking Router Service")
    }


    public func countBookings(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countBookings")
        adapterFactory.getBookingAdapter().getNumberOfBookings { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    public func createBooking(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {

        guard let body = request.body else {
            try response.status(.badRequest).end()
            return
        }

        guard case .urlEncoded(let params) = body else {
            try response.status(.badRequest).end()
            return
        }

        let userid = params["userid"]?.removingPercentEncoding ?? ""
        let toFlight = params["toFlightId"] ?? ""
        let retFlight = params["retFlightId"] ?? ""
        let isOneWay = params["oneWayFlight"] ?? ""

        Log.info("userid: \(userid), toFlight: \(toFlight), retFlight: \(retFlight), isOneWay: \(isOneWay)")
        var responseJson: [String: String] = [:]
        let adapter = adapterFactory.getBookingAdapter()

        responseJson["oneWay"] = isOneWay
        adapter.createBooking(userid: userid, toFlightId: toFlight, retFlightId: retFlight) {  result in
            switch result {
            case .success(let booking):
                responseJson["departBookingId"] = booking._id
            default:
                responseJson["departBookingId"] = ""
            }
        }
        if isOneWay == "false" {
            adapter.createBooking(userid: userid, toFlightId: retFlight, retFlightId: retFlight) { result in
                 switch result {
                 case .success(let booking):
                     responseJson["returnBookingId"] = booking._id
                 default:
                     responseJson["returnBookingId"] = ""
                 }
            }
        }
        response.send(json: JSON(responseJson))
        next()
    }
    
    func cancelBooking(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {

        guard let body = request.body else {
            try response.status(.badRequest).end()
            return
        }

        guard case .urlEncoded(let params) = body else {
            try response.status(.badRequest).end()
            return
        }

        let number = params["number"] ?? ""
        let userid = params["userid"]?.removingPercentEncoding ?? ""
        let adapter = adapterFactory.getBookingAdapter()
        
        adapter.cancelBooking(number: number, userid: userid) {  result in
            if case .success(_) = result {
                response.send(json: JSON(["status": "success"]))  //to match the acmeair-nodejs code
                next()
            } else {
                response.send(json: JSON(["status": "error"]))  //to match the acmeair-nodejs code
                next()
            }
        }
    }
    
    func getBooking(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        guard let userid = request.parameters["userid"]?.removingPercentEncoding else {
            response.status(.badRequest)
            next()
            return
        }
        Log.info("bookingsByUser Handler: \(userid)")
        
        var arrayBooking : [Any] = []
        let adapter = adapterFactory.getBookingAdapter()
        adapter.getBooking(userid: userid) { result in
            if case .success(let bookings) = result, let bs = bookings  {
                for bookingObj in bs {
                    arrayBooking.append(bookingObj.toDict())
                }
                Log.info("RESULTS:\(arrayBooking)")
                response.send(json: JSON(arrayBooking))
                next()
            } else {
                response.send(json: JSON(arrayBooking)) //to match the acmeair-nodejs behavior
                next()
            }
        }
    }
}

