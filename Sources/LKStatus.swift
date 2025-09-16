//
//  LKStatus.swift
//  LatencyKit
//
//  Created by 김수환 on 8/27/25.
//

import Foundation

public enum LKStatus {
    
    case slow(rtt: Double, throughputByte: Double)
    case medium(rtt: Double, throughputByte: Double)
    case fast(rtt: Double, throughputByte: Double)
}
