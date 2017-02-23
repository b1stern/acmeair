//The AcmeAir launcher

import MongodbAdapters
import LoggerAPI
import HeliumLogger
import Foundation
import AcmeAir

HeliumLogger.use(.warning)

let dbHost = ProcessInfo.processInfo.environment["DB_HOST"] ?? "localhost"
let dbPort = ProcessInfo.processInfo.environment["DB_PORT"] ?? "27017"
let serverPort = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8090") ?? 8090

if let mongodbAdapterFactory = try MongodbAdapterFactory.createFactory(properties: ["dbName": "acmeair", "host": dbHost, "port": dbPort],
                                                                configurationPath: nil) {
 
    let acmeairServer = AcmeAir(port: serverPort, factory: mongodbAdapterFactory)
    acmeairServer.run()
} else {
    Log.error("Unable to start Acmeair")
}
    
