// SPDX-License-Identifier: AGPL-3.0-only
//
// ControllerInputMapper.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Mapper for controller input conversion, decoupled from StreamingViewModel
//

import Foundation

/**
 * 控制器输入映射器
 * @requirement F-012 - 架构解耦与重构
 * @satisfies AC-039 - 提取输入映射模块
 */
struct ControllerInputMapper {
    
    /**
     * 将虚拟按钮映射到 Chiaki 协议按钮
     * @satisfies AC-039
     */
    func map(_ button: VirtualControllerButton) -> ChiakiControllerButtons {
        switch button {
        case .cross: return .cross
        case .circle: return .moon
        case .square: return .box
        case .triangle: return .pyramid
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .l1: return .l1
        case .l2: return .l2
        case .r1: return .r1
        case .r2: return .r2
        case .share: return .share
        case .options: return .options
        case .ps: return .ps
        }
    }
}
