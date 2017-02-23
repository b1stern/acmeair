import Kitura
import LoggerAPI
import SwiftyJSON

public class StatusResource: Resource {

    public init(router: Router) {
        super.init()
        setupRoutes(router: router)
    }

    func setupRoutes(router: Router) {
        router.get(Resource.baseRoute + "checkstatus", handler: respondToPing)
        router.get(Resource.baseRoute + "config/runtime", handler: getRuntimeInfo)
        router.get(Resource.baseRoute + "config/dataServices", handler: getDataServices)
        router.get(Resource.baseRoute + "config/activeDataService", handler: getActiveDataService)
    }

    func respondToPing(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        response.status(.OK)
        next()
        return
    }

    func getRuntimeInfo(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        let packages = "[{\"name\": \"Kitura v1\", \"description\":\"A Swift web framework and HTTP server\"}," +
                        "{\"name\": \"HeliumLogger v1\", \"description\":\"A lightweight logging framework for Swift\"}," +
                        "{\"name\": \"SwiftyJSON v15\", \"description\":\"A framework to deal with JSON data in Swift\"}," +
                        "{\"name\": \"acmeair-adapters\", \"description\":\"Generic adapter protocols for Acme Air\"}," +
                        "{\"name\": \"acmeair-mongodb-adapters\", \"description\": \"MondoDb adapters for AcmeAir\"}]"
        let encodedString = packages.data(using: String.Encoding.utf8)!
        response.send(json: JSON(data: encodedString))
        next()
        return
    }

    func getDataServices(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        let dataServices = "[{\"name\":\"cassandra\",\"description\":\"Apache Cassandra NoSQL DB\"}," +
		           "{\"name\":\"cloudant\",\"description\":\"IBM Distributed DBaaS\"}," +
		           "{\"name\":\"mongo\",\"description\":\"MongoDB NoSQL DB\"}]"
        let encodedString = dataServices.data(using: String.Encoding.utf8)!
        response.send(json: JSON(data: encodedString))
        next()
        return
    }

    func getActiveDataService(request: RouterRequest, response: RouterResponse, next: @escaping() -> Void) throws {
        response.send("mongodb") //constant for now
        next()
        return
    }
}
