import Kitura
import Adapters
import LoggerAPI
import Helpers

public class CustomerResource: Resource {
    
    private let customerAdapter: CustomerAdapter
    
    public init(router: Router, factory: AdapterFactory) {
        self.customerAdapter = factory.customerAdapter
        super.init()
        
        setupRoutes(router: router)
    }
    
    func setupRoutes(router: Router) {
        router.all("/*", middleware: BodyParser()) // TODO: Move this to Common place
        router.get(Resource.baseRoute + "customer/byid/:customerId", handler: getCustomerHandler)
        router.post(Resource.baseRoute + "customer/byid/:customerId", handler: postCustomerHandler)
        router.get(Resource.baseRoute + "config/countCustomers", handler: countCustomers)
        Log.info("Customer Router Initialized")
    }

    func countCustomers(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countCustomers")
        customerAdapter.getNumberOfCustomers { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    /*
     Handles getCustomer Request
     */
    func getCustomerHandler(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("getCustomerHandler")
        
        guard let customerId = request.parameters["customerId"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        customerAdapter.getCustomer(withID: customerId) { result in

            switch(result) {
                case .success(let customer):
                    response.send(json: customer.json)
                    next()

                case .failure(_):
                    response.status(.notFound)
                    next()
            }
        }
    }
    
    /*
     Handles Post Customer Request
     */
    func postCustomerHandler(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("postCustomerHandler")
        
        guard let customerId = request.parameters["customerId"] else {
            response.status(.badRequest)
            next()
            return
        }
        
        Log.debug("customerId: \(customerId)")
        // Get JSON object
        guard let json = request.json else {
            response.status(.badRequest).send("Invalid Request")
            next()
            return
        }

        let password = json["password"].stringValue
        let status = json["status"].stringValue
        let total_miles = json["total_miles"].intValue
        let miles_ytd = json["miles_ytd"].intValue
        let streetAddress1 = json["address"]["streetAddress1"].stringValue
        let streetAddress2 = json["address"]["streetAddress2"].stringValue
        let city = json["address"]["city"].stringValue
        let stateProvince = json["address"]["stateProvince"].stringValue
        let country = json["address"]["country"].stringValue
        let postalCode = json["address"]["postalCode"].stringValue
        
        let phoneNumber = json["phoneNumber"].stringValue
        let phoneNumberType = json["phoneNumberType"].stringValue
        
        customerAdapter.updateCustomer(withID: customerId, password: password, status: status, totalMiles: total_miles, totalMilesYTD: miles_ytd, phoneNumber: phoneNumber, phoneNumberType: phoneNumberType, streetAddress1: streetAddress1, streetAddress2: streetAddress2, city: city, stateProvince: stateProvince, country: country, postalCode: postalCode) { result in
            
            switch(result) {
                case .success(let customer):
                    Log.info("Customer obj: \(customer.json)")
                    response.send(json: customer.json)
                    next()

                case .failure(_):
                    response.status(.notFound)
                    next()
            }

        }
    }
}
