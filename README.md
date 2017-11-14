# TitanSwiftHTTPAdapter

This repository provides an adapter between the prototype [`swift/http`](https://github.com/swift-server/http) package and Titan, a no-nonsense microframework for writing HTTP speaking services in Swift.

## Installation

Because none of us can remember the SPM syntax:

```swift
.package(url: "https://github.com/swift-server/http.git", from: "0.1.0")
.package(url: "https://github.com/bermudadigitalstudio/TitanSwiftHTTPAdapter.git", from: "0.1.0")
```

## Usage

After creating your Titan app, generate a handler like so:

```swift
import Titan

let titanInstance = Titan()
titan.addFunction...

import TitanSwiftHTTPAdapter
import HTTP

let httpHandler = httpRequestHandlerFromTitanApp(titanInstance.app)
let server = HTTPServer()
try server.start(port: Int(port), handler: httpHandler)
```

## Development

`./Scripts/test.sh` will run the tests in a Docker container. `swift package generate-xcodeproj` will do the rest, as you need it.
