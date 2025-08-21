//
//  LKThroughputChecker.swift
//  LatencyKit
//
//  Created by 김수환 on 8/21/25.
//

import Foundation
import Combine

public final actor LKThroughputChecker {
    
    public static let shared = LKThroughputChecker()
    
    public func setMinimumTotalByte(_ byte: Int64) {
        self.minimumTotalByte = byte
    }
    
    public func setMinimumWindowSize(_ byte: Int64) {
        self.minimumWindowSize = byte
    }
    
    var minimumTotalByte: Int64 = 32000 // 32KB
    var minimumWindowSize: Int64 = 5_000_000 // 5MB
    
    
    let throughputPublisher = PassthroughSubject<Double, Never>()
    
    // MARK: - Opened Task
    
    func appendConcurrentRequest() async {
        concurrentRequests += 1
    }
    
    func removeConcurrentRequest() async {
        concurrentRequests -= 1
        if concurrentRequests < Constant.windowSize {
            await closeWindowIfNeeded()
        }
    }
    
    // MARK: - Window
    
    func openWindowIfNeeded() async {
        guard !isWindowOpened,
              concurrentRequests > Constant.windowSize
        else {
            return
        }
        await openWindow()
    }
    
    func openWindowIfContentLarge(length: Int64) async {
        guard !isWindowOpened,
              length > minimumWindowSize
        else {
            return
        }
        await openWindow()
    }
    
    private func openWindow() async {
        isWindowOpened = true
        timeStamp = Date()
    }
    
    func closeWindowIfNeeded() async {
        guard isWindowOpened else { return }
        isWindowOpened = false
        
        let date = Date()
        let timeElapsed = date.timeIntervalSince(timeStamp ?? date)
        if totalByte > minimumTotalByte {
            let throughput = Double(totalByte) / timeElapsed
            throughputPublisher.send(throughput)
        }
        totalByte = 0
        timeStamp = nil
    }
    
    // MARK: - Data
    
    func appendTotalByteIfNeeded(_ byte: Int64) async {
        guard isWindowOpened else {
            await openWindowIfNeeded()
            return
        }
        totalByte += byte
    }
    
    // MARK: - Attribute
    
    private var isWindowOpened = false {
        didSet {
            timeoutCancellable?.cancel()
            if isWindowOpened {
                timeoutCancellable = Just(())
                    .delay(for: .seconds(Constant.windowTimeout), scheduler: DispatchQueue.global())
                    .sink { [weak self] _ in
                        Task {
                            await self?.closeWindowIfNeeded()
                        }
                    }
            }
        }
    }
    private var concurrentRequests: Int = 0
    private var totalByte: Int64 = 0
    private var timeStamp: Date?
    private var timeoutCancellable: AnyCancellable?
}

// MARK: - Constant

private extension LKThroughputChecker {
    
    enum Constant {
        
        static let windowSize: Int = 5
        static let windowTimeout: TimeInterval = 10
    }
}
