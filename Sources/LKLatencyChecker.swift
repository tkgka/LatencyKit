//
//  LKLatencyChecker.swift
//  LatencyKit
//
//  Created by 김수환 on 8/21/25.
//

import Foundation
import Combine

final actor LKLatencyActor {
    
    static let shared = LKLatencyActor()
    
    func calculateStatus() -> LKStatus {
        let currentTime = Date()
        let elapsedSeconds = currentTime.timeIntervalSince(throughputCheckTime ?? currentTime)
        let rtt = rtt ?? rttReferenceMillisecond
        let throughput = throughput ?? throughputReferenceByte
        let rttScore = 1 - min((rtt * 2) / rttReferenceMillisecond, 1)
        let throughputScore = 1 - min((throughput / 5) / throughputReferenceByte, 1)
        
        let timeWeight = min(max(cos(min(elapsedSeconds / timeConstant, 1) * .pi / 2), 0), 1)
        let throughputWeight = baseThroughputWeight * timeWeight
        let rttWeight = 1 - throughputWeight
        
        // 6. 최종 네트워크 성능 점수 계산
        let networkPerformance = min(max(rttWeight * rttScore + throughputWeight * throughputScore, 0.0), 1.0)
        if networkPerformance > 0.7 {
            return .fast(rtt: rtt, throughputByte: throughput)
        }
        if networkPerformance > 0.3 {
            return .medium(rtt: rtt, throughputByte: throughput)
        }
        return .slow(rtt: rtt, throughputByte: throughput)
    }
    
    func updateRTT(to rtt: Double) -> LKStatus {
        self.rtt = rtt
        return calculateStatus()
    }
    
    func updateThrughput(to throughput: Double) -> LKStatus {
        self.throughput = throughput
        throughputCheckTime = Date()
        return calculateStatus()
    }
    
    func setTimeConstant(_ timeConstant: CGFloat) {
        self.timeConstant = timeConstant
    }
    func setThroughputReferenceByte(_ throughputReferenceByte: CGFloat) {
        self.throughputReferenceByte = throughputReferenceByte
    }
    
    func setRttReferenceMillisecond(_ rttReferenceMillisecond: CGFloat) {
        self.rttReferenceMillisecond = rttReferenceMillisecond
    }
    
    func setBaseThroughputWeight(_ baseThroughputWeight: CGFloat) {
        self.baseThroughputWeight = baseThroughputWeight
    }
    
    private var rtt: Double?
    private var throughputCheckTime: Date?
    private var throughput: Double?
    
    private var timeConstant: CGFloat = 60.0 // 1분 후 throughput 가중치가 0이 되도록
    private var throughputReferenceByte: CGFloat = 100000000.0 // 100 MB
    private var rttReferenceMillisecond: CGFloat = 50.0 // 50ms
    private var baseThroughputWeight: CGFloat = 0.6
}

final class LKLatencyChecker: NSObject {
    
    // MARK: - Interface
    
    let output: PassthroughSubject<LKStatus, Error>
    
    // MARK: - Initialization
    
    init(
        timeConstant: CGFloat,
        throughputReferenceByte: CGFloat,
        rttReferenceMillisecond: CGFloat,
        baseThroughputWeight: CGFloat,
        _ output: PassthroughSubject<LKStatus, Error>
    ) {
        self.output = output
        super.init()
        Task {
            await LKLatencyActor.shared.setTimeConstant(timeConstant)
            await LKLatencyActor.shared.setThroughputReferenceByte(throughputReferenceByte)
            await LKLatencyActor.shared.setRttReferenceMillisecond(rttReferenceMillisecond)
            await LKLatencyActor.shared.setBaseThroughputWeight(baseThroughputWeight)
        }
        bind()
    }
    
    private func bind() {
        Task {
            await bindRTT()
            await bindThroughput()
        }
    }
    
    // MARK: - Attribute
    
    private var cancellables: Set<AnyCancellable> = []
}

// MARK: - RTT

extension LKLatencyChecker {
    
    func bindRTT() async {
        await LKRTTChecker.shared.rttPublisher
            .sink { rtt in
                Task {
                    let status = await LKLatencyActor.shared.updateRTT(to: rtt)
                    self.output.send(status)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Throughput

extension LKLatencyChecker {
    
    func bindThroughput() async {
        await LKThroughputChecker.shared.throughputPublisher
            .sink { throughput in
                Task {
                    let status = await LKLatencyActor.shared.updateThrughput(to: throughput)
                    self.output.send(status)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Delegate

extension LKLatencyChecker: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        Task {
            await LKThroughputChecker.shared.appendConcurrentRequest()
            await LKThroughputChecker.shared.openWindowIfNeeded()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {} // TODO: -
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task {
            await LKThroughputChecker.shared.appendTotalByteIfNeeded(Int64(data.count))
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, contentLength: Double) {
        Task {
            await LKThroughputChecker.shared.openWindowIfContentLarge(length: Int64(contentLength))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task {
            await LKThroughputChecker.shared.removeConcurrentRequest()
        }
        if let error {
            output.send(completion: .failure(error))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Task {
            await LKRTTChecker.shared.calculate(metrics: metrics)
        }
    }
}
