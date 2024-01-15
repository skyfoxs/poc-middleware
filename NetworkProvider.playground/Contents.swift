import Foundation

class Network {
    typealias CompletionFunc<T> = (Result<T, NetworkError>) -> Void
    typealias RequestFunc<T> = (Request, @escaping CompletionFunc<T>) -> Void

    struct Middleware<A,B> {
        let apply: (@escaping RequestFunc<A>) -> RequestFunc<B>

        func with<C>(middleware: Middleware<C,A>) -> Middleware<C,B> {
            Middleware<C,B> { next in
                { request, completionFunc in
                    apply(middleware.apply(next))(request, completionFunc)
                }
            }
        }
    }

    class Provider<R> {
        private var middleware: Middleware<Data, R>

        init(middleware: Middleware<Data, R>) {
            self.middleware = middleware
        }

        func request(with request: Request, completion: @escaping CompletionFunc<R>) {
            middleware
                .apply({ request, completion in
                    print("loading...", request.urlRequest)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        completion(
                            .success(
                            """
                            {
                                "token": "123456"
                            }
                            """.data(using: .utf8)!
                            )
                        )
                    }
                })(request, completion)
        }
    }
}

struct NetworkError: Error {}

struct Request {
    let urlRequest: URLRequest
}

func makeDecodeMiddleware<T: Decodable>(for type: T.Type) -> Network.Middleware<Data, T> {
    Network.Middleware { next in
        { request, completionFunc in
            next(request, { response in
                print("decoding...")
                switch response {
                case .success(let data):
                    completionFunc(.success(try! JSONDecoder().decode(T.self, from: data)))
                case .failure: break
                }
            })
        }
    }
}

func makeLoadingMiddleware<T>(for type: T.Type) -> Network.Middleware<T, T> {
    Network.Middleware { next in
        { request, completionFunc in
            print("display loading")
            next(request, { response in
                completionFunc(response)
                print("hide loading")
            })
        }
    }
}

let contentSignatureMiddleware = Network.Middleware<Data, Data> { next in
    { request, completionFunc in
        print("encode request")
        next(request, { response in
            print("decode")
            completionFunc(response)
        })
    }
}

struct Session: Decodable {
    let token: String
}

Network.Provider(
    middleware: makeLoadingMiddleware(for: Session.self)
        .with(middleware: makeDecodeMiddleware(for: Session.self))
        .with(middleware: contentSignatureMiddleware)
)
.request(with: Request(urlRequest: URLRequest(url: URL(string: "https://www.google.com")!))) { result in
    switch result {
    case .success(let session):
        print("enter caller completion")
        print(session)
        print("end")
    case .failure: break
    }
}


//Network.Provider(
//    middleware: makeLoadingMiddleware(for: Data.self)
//        .with(middleware: contentSignatureMiddleware)
//)
//.request(with: Request(urlRequest: URLRequest(url: URL(string: "https://www.google.com")!))) { result in
//    switch result {
//    case .success(let data):
//        print("enter caller completion")
//        print(data)
//        print("end")
//    case .failure: break
//    }
//}
