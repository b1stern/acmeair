import PackageDescription

let package = Package(
    name: "Acmeair",

     targets: [
        Target(
            name: "AcmeAir",
            dependencies: []
        ),
        Target(
            name: "Server",
            dependencies: [.Target(name: "AcmeAir")]
        ),
    ],

    dependencies:[
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1),
        .Package(url: "git@github.ibm.com:IBM-Swift/acmeair-adapters.git", majorVersion: 0),
        .Package(url: "git@github.ibm.com:IBM-Swift/acmeair-mongodb-adapters.git", majorVersion: 0),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/SwiftyJSON.git", majorVersion: 15),
    ]
)
