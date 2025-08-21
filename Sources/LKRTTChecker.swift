//
//  LKRTTChecker.swift
//  LatencyKit
//
//  Created by 김수환 on 8/21/25.
//

import Foundation
import Combine

public final actor LKRTTChecker {
    
    // MARK: - Interface
    
    public static let shared = LKRTTChecker()
    
    let rttPublisher = PassthroughSubject<Double, Never>()
    
    private(set) var smoothedRTT: Double = 0 {
        didSet {
            rttPublisher.send(smoothedRTT)
        }
    }
    
    public func setWeight(_ weight: Double) {
        self.weight = weight
    }
    
    public var weight : Double = 0.125
    
    func calculate(metrics: URLSessionTaskMetrics) {
        let rtt = calculateRTT(metrics) ?? 0
        smoothedRTT = (1 - weight) * smoothedRTT + weight * rtt
    }
    
    // MARK: - Calculate
    
    private func calculateRTT(_ metrics: URLSessionTaskMetrics) -> Double? {
        guard let tx = metrics.transactionMetrics.last,
              let requestStartTime = tx.requestStartDate,
              let rsponseStartTime = tx.responseStartDate else {
            return nil
        }
        return rsponseStartTime.timeIntervalSince(requestStartTime) * 1000 // ms
    }
}
