// Predictably, the following crashes the compiler, so we have to import the 
// whole damn module
//import typealias HTTP.HTTPRequestHandler
import HTTP
import TitanCore
import Dispatch
import Foundation

/// Returns an `HTTPBodyProcessing` case that, when completed or errored,
/// will send all received data, any trailing headers, and the error, if there was one in the completion closure.
func accumulateData(_ completion: @escaping (DispatchData?, [(String, String)], Error?) -> Void) -> HTTPBodyProcessing {
    var dataAccumulator: DispatchData? = nil
    var trailingHeaderAccumulator: [(String, String)] = []
    var didComplete: Bool = false
    return .processBody { chunk, _ in
        switch chunk {
        case let .chunk(data, finishedProcessing):
            guard dataAccumulator != nil else {
                dataAccumulator = data
                finishedProcessing()
                break
            }
            dataAccumulator!.append(data)
            finishedProcessing()
        case let .failed(error):
            guard didComplete == false else {
                // We've somehow already fired the completion
                break
            }
            completion(dataAccumulator, trailingHeaderAccumulator, error)
            didComplete = true
            break
        case .end:
            guard didComplete == false else {
                // We've somehow already fired the completion
                break
            }
            completion(dataAccumulator, trailingHeaderAccumulator, nil)
            break
        case let .trailer(pair):
            trailingHeaderAccumulator.append(pair)
            break
        }
    }
}

public func httpRequestHandlerFromTitanApp(_ app: @escaping (RequestType) -> (ResponseType)) -> HTTPRequestHandler {
    return { hRequest, httpResponseWriter -> HTTPBodyProcessing in
        return accumulateData { (data, trailers, error) in
            guard error == nil else {
                /// When an error occurs, something weird has happened in the transport layer.
                /// Titan has no semantics to handle that, so we're just going to abort and pretend like we never received the request.
                print("Connection error inside Swift HTTP library. See line \(#line) in file \(#file) for more details.")
                return
            }
            let foundationData: Data

            if let dispatchData = data {
                foundationData = dispatchData.withUnsafeBytes { (ptr: UnsafePointer<Int8>) -> Data in
                    return Data(bytes: ptr, count: dispatchData.count) // This is the safe but inefficient route. We really should find a way to take ownership of the underlying bytes of the DispatchData object.
                }
            } else {
                foundationData = Data()
            }
            var titanRequestHeaders: [(String, String)] = []
            for header in hRequest.headers {
                titanRequestHeaders.append((header.name.description, header.value))
            }
            titanRequestHeaders.append(contentsOf: trailers)
            let titanRequest = Request(method: hRequest.method.description, path: hRequest.target, body: foundationData, headers: titanRequestHeaders)
            // Execute the Titan App!
            let titanResponse = app(titanRequest)
            
            let titanResponseHeaders: [(HTTPHeaders.Name, String)] = titanResponse.headers.map({ (header) in
                return (HTTPHeaders.Name(header.name), header.value)
            })
            var headers: HTTPHeaders = [:]
            for (name, value) in titanResponseHeaders {
                headers[name] = value
            }
            httpResponseWriter.writeHeader(status: HTTPResponseStatus(code: titanResponse.code), headers: headers)
            httpResponseWriter.writeBody(titanResponse.body)
            httpResponseWriter.done()
        }
    }
}
