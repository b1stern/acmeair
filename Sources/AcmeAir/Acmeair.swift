import Kitura
import Adapters

public class AcmeAir {

    let router: Router
    let port: Int

    public init(port: Int, factory: AdapterFactory) {
        self.router = Router()
        self.port = port
        router.all("/", middleware: StaticFileServer())
        let _ = CustomerResource(router: router, factory: factory)
        let _ = FlightResource(router: router, factory: factory)
        let _ = BookingResource(router: router, factory: factory)
        let _ = CustomerSessionResource(router: router, factory: factory)
        let _ = StatusResource(router: router)
        let _ = LoaderResource(router: router)
    }

    public func run() {
        Kitura.addHTTPServer(onPort: port, with: router)
        Kitura.run()
    }

    public func start() {
       Kitura.addHTTPServer(onPort: port, with: router)
       Kitura.start()
    }

    public func stop() {
        Kitura.stop()
    }
}
