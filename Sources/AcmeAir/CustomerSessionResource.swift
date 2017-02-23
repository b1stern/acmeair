import Kitura
import Adapters
import LoggerAPI
import Helpers
import Foundation

public class CustomerSessionResource: Resource {

    private let customerAdapter: CustomerAdapter
    private let customerSessionAdapter: CustomerSessionAdapter

    public init(router: Router, factory: AdapterFactory) {
        self.customerAdapter = factory.customerAdapter
        self.customerSessionAdapter = factory.customerSessionAdapter
        super.init()
        setupRoutes(router: router)
    }

    func setupRoutes(router: Router) {
        router.post(Resource.baseRoute + "login", handler: loginHandler)
        router.get(Resource.baseRoute + "login/logout", handler: logoutHandler)
        router.get(Resource.baseRoute + "config/countSessions", handler: countSessions)
        Log.info("Customer Router Initialized")
    }

    public func countSessions(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        Log.info("countSessions")
        customerSessionAdapter.getNumberOfCustomerSessions { result in
            switch result {
                case .success(let count):
                    response.send("\(count)")
                case .failure:
                    response.send("-1")
            }
            next()
        }
    }

    func loginHandler(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {

        guard let body = request.body else {
            response.status(.badRequest).send("Invalid Request")
            next()
            return
        }
        
        guard case .urlEncoded(let params) = body else {
            try response.status(.badRequest).end()
            return
        }

        let userid = params["login"]?.removingPercentEncoding ?? ""
        let password = params["password"] ?? ""
        
        customerAdapter.getCustomer(withID: userid) { result in
            switch result {
            case .success(let customer): 
                guard customer.json["password"].stringValue == password else {
                    Log.info("Login failure")
                    response.status(.forbidden).send("login failed")
                    next()
                    return
                }

                let now = Date()
                let later = now.addingTimeInterval(1000*60*60*24.0)
                self.customerSessionAdapter.saveSession(id: UUID().uuidString, customerId: userid,
                    lastAccessedTime: now, timeoutTime: later) { result in
                        if case .success(_) = result {
                            response.status(.OK).send("logged in")
                            next()
                        } else { 
                            response.status(.forbidden).send("login failed")
                            next()
                        }
                    }
  
            case .failure(_):
                Log.info("Login failure")
                response.status(.forbidden).send("login failed")
                next()
            }
          
        }
    }

    func logoutHandler(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        guard let userid = request.queryParameters["login"] else {
                Log.info("Logout failure")
                response.status(.forbidden).send("logout failed")
                next()
                return
        }

        customerAdapter.getCustomer(withID: userid) { result in
            switch result {
            case .success(_):
                Log.info("Todo")
                response.status(.OK).send("logged out")
                next()

            case .failure(_):
                Log.info("Logout failure")
                response.status(.forbidden).send("logout failed")
                next()
            }

        }
    }

}
