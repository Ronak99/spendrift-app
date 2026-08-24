//
//  SentryTunnelURLProtocol.swift
//  Spendrift
//
//  sentry-cocoa has no `options.tunnel` (unlike the JS SDK). A dedicated
//  `URLSession` with this protocol redirects envelope transport to our
//  first-party `/ingest` endpoint.
//

import Foundation

final class SentryTunnelURLProtocol: URLProtocol {
    static var tunnelURL: URL?

    private static let handledKey = "SpendriftSentryTunnelHandled"

    override class func canInit(with request: URLRequest) -> Bool {
        guard tunnelURL != nil else { return false }
        return property(forKey: handledKey, in: request) == nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        guard let tunnelURL else { return request }
        var redirected = request
        redirected.url = tunnelURL
        return redirected
    }

    private var dataTask: URLSessionDataTask?

    override func startLoading() {
        guard let tunnelURL = Self.tunnelURL else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        mutable.url = tunnelURL
        Self.setProperty(true, forKey: Self.handledKey, in: mutable)

        let session = URLSession(configuration: .ephemeral)
        dataTask = session.dataTask(with: mutable as URLRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }
}
