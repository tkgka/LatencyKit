//
//  LKLatencyCheckSession.swift
//  LatencyKit
//
//  Created by 김수환 on 8/22/25.
//

import Foundation
import Combine

public final class LKLatencyCheckSession {
    
    public static func make(
        with latencyChangePublisher: PassthroughSubject<LKStatus, Error>,
        timeConstant: CGFloat = 60.0,
        throughputReferenceByte: CGFloat = 100000000.0,
        rttReferenceMillisecond: CGFloat = 50.0,
        rttWeight: Double = 0.125,
        baseThroughputWeight: CGFloat = 0.6,
        config: URLSessionConfiguration = URLSessionConfiguration.default,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) -> URLSession {
        var delegates: [URLSessionDelegate] = [LKLatencyChecker(
            timeConstant: timeConstant,
            throughputReferenceByte: throughputReferenceByte,
            rttReferenceMillisecond: rttReferenceMillisecond,
            baseThroughputWeight: baseThroughputWeight,
            latencyChangePublisher)]
        if let delegate {
            delegates.append(delegate)
        }
        let compositeDelegate = CompositeDelegate(delegates)
        let session = URLSession(configuration: config, delegate: compositeDelegate, delegateQueue: delegateQueue)
        return session
    }
}

final class CompositeDelegate: NSObject, URLSessionTaskDelegate {
    
    // MARK: - Initialization
    
    init(_ ds: [URLSessionDelegate]) { self.delegates = ds }
    
    // MARK: - Attribute
    
    private let delegates: [URLSessionDelegate]
}

// MARK: - URLSessionDelegate

extension CompositeDelegate {
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        delegates.forEach { $0.urlSession?(session, didBecomeInvalidWithError: error) }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegates.forEach { $0.urlSession?(session, didReceive: challenge, completionHandler: completionHandler) }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let delegate = delegates.last { // I don't know why await delegates.last?.urlSession?(session, didReceive: challenge) ?? .... fail to build
            if delegate.responds(to: #selector(URLSessionDelegate.urlSession(_:didReceive:))) {
                return await delegate.urlSession!(session, didReceive: challenge)
            }
        }
        return (URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        delegates.forEach { $0.urlSessionDidFinishEvents?(forBackgroundURLSession: session) }
    }
}

// MARK: - URLSessionTaskDelegate

extension CompositeDelegate {
    
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, didCreateTask: task)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        (delegates.last as? URLSessionTaskDelegate)?.urlSession?(session, task: task, willBeginDelayedRequest: request, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest) async -> (URLSession.DelayedRequestDisposition, URLRequest?) {
        if let delegate = (delegates.last as? URLSessionTaskDelegate) {
            if delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:task:willBeginDelayedRequest:))) {
                return await delegate.urlSession!(session, task: task, willBeginDelayedRequest: request)
            }
        }
        return (URLSession.DelayedRequestDisposition.continueLoading, nil)
    }
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, taskIsWaitingForConnectivity: task)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        (delegates.last as? URLSessionTaskDelegate)?.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        if let delegate = (delegates.last as? URLSessionTaskDelegate) {
            if delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:))) {
                return await delegate.urlSession!(session, task: task, willPerformHTTPRedirection: response, newRequest: request)
            }
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        (delegates.last as? URLSessionTaskDelegate)?.urlSession?(session, task: task, needNewBodyStream: completionHandler)
    }
    
    
    func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
        if let delegate = (delegates.last as? URLSessionTaskDelegate) {
            if delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:needNewBodyStreamForTask:))) {
                return await delegate.urlSession!(session, needNewBodyStreamForTask: task)
            }
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStreamFrom offset: Int64, completionHandler: @escaping (InputStream?) -> Void) {
        (delegates.last as? URLSessionTaskDelegate)?.urlSession?(session, task: task, needNewBodyStreamFrom: offset, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask, from offset: Int64) async -> InputStream? {
        if let delegate = (delegates.last as? URLSessionTaskDelegate) {
            if delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:needNewBodyStreamForTask:))) {
                return await delegate.urlSession!(session, needNewBodyStreamForTask: task, from: offset)
            }
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesSent)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceiveInformationalResponse response: HTTPURLResponse) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, task: task, didReceiveInformationalResponse: response)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, task: task, didFinishCollecting: metrics)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionTaskDelegate {
                delegate.urlSession?(session, task: task, didCompleteWithError: error)
            }
        }
    }
}

// MARK: - URLSessionDataDelegate

extension CompositeDelegate: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        if let contentLength = ((response as? HTTPURLResponse)?.allHeaderFields["Content-Length"] as? NSString)?.doubleValue {
            (delegates.first as? LKLatencyChecker)?.urlSession(session, dataTask: dataTask, contentLength: contentLength)
        }
        guard let delegate = delegates.last as? URLSessionDataDelegate else {
            return .allow
        }
        return await delegate.urlSession?(session, dataTask: dataTask, didReceive: response) ?? .allow
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let delegate = delegates.last as? URLSessionDataDelegate else {
            return
        }
        delegate.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        guard let delegate = delegates.last as? URLSessionDataDelegate else {
            return
        }
        delegate.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        delegates.forEach {
            if let delegate = $0 as? URLSessionDataDelegate {
                delegate.urlSession?(session, dataTask: dataTask, didReceive: data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse) async -> CachedURLResponse? {
        guard let delegate = delegates.last as? URLSessionDataDelegate else {
            return nil
        }
        if delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:willCacheResponse:))) {
            return await delegate.urlSession!(session, dataTask: dataTask, willCacheResponse: proposedResponse)
        }
        return nil
    }
}

// MARK: - URLSessionDownloadDelegate

extension CompositeDelegate: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let delegate = delegates.last as? URLSessionDownloadDelegate else {
            return
        }
        delegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        guard let delegate = delegates.last as? URLSessionDownloadDelegate else {
            return
        }
        delegate.urlSession?(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let delegate = delegates.last as? URLSessionDownloadDelegate else {
            return
        }
        delegate.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
}

// MARK: - URLSessionStreamDelegate

extension CompositeDelegate: URLSessionStreamDelegate {
    
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        guard let delegate = delegates.last as? URLSessionStreamDelegate else {
            return
        }
        delegate.urlSession?(session, readClosedFor: streamTask)
    }
    
    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        guard let delegate = delegates.last as? URLSessionStreamDelegate else {
            return
        }
        delegate.urlSession?(session, writeClosedFor: streamTask)
    }
    
    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        guard let delegate = delegates.last as? URLSessionStreamDelegate else {
            return
        }
        delegate.urlSession?(session, betterRouteDiscoveredFor: streamTask)
    }
    
    func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
        guard let delegate = delegates.last as? URLSessionStreamDelegate else {
            return
        }
        delegate.urlSession?(session, streamTask: streamTask, didBecome: inputStream, outputStream: outputStream)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension CompositeDelegate: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard let delegate = delegates.last as? URLSessionWebSocketDelegate else {
            return
        }
        let protocolString = String(describing: `protocol`)
        delegate.urlSession?(session, webSocketTask: webSocketTask, didOpenWithProtocol: protocolString)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard let delegate = delegates.last as? URLSessionWebSocketDelegate else {
            return
        }
        delegate.urlSession?(session, webSocketTask: webSocketTask, didCloseWith: closeCode, reason: reason)
    }
}
