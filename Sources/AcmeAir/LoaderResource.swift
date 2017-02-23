import Kitura
import LoggerAPI
import Loader

public class LoaderResource: Resource {

    public init(router: Router) {
        super.init()
        setupRoutes(router: router)
    }

    func setupRoutes(router: Router) {
        router.get(Resource.baseRoute + "loader/load", handler: loadDb)
        router.get(Resource.baseRoute + "loader/query", handler: getNumConfiguredCustomers)
    }

    func loadDb(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        
        var customers = 100
        if let param = request.queryParameters["numCustomers"], let numCustomers = Int(param) {
            customers = numCustomers
        }
        
        let loader = try MongoDBLoader()
        do {
            try loader.loadDatabase(noOfCustomers: customers)
            response.send("Database Finished Loading")
        } catch {
            Log.error("Failed to load database with error: \(error)")
            response.status(.badRequest)
        }
        next()
        return
    }

    func getNumConfiguredCustomers(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        response.headers["Content-Type"] = "text/plain"
        response.send(String(MongoDBLoader.MAX_CUSTOMERS))
        next()
        return
    }

}

