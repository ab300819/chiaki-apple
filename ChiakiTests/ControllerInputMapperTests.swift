//
//  ControllerInputMapperTests.swift
//  ChiakiTests
//
//  Unit tests for ControllerInputMapper (UT-11.2)
//

import Testing
import Foundation
@testable import Chiaki

struct ControllerInputMapperTests {

    /**
     * @verifies AC-039 - 架构解耦：提取输入映射模块
     * @testcase UT-11.2
     */
    @Test func testMapVirtualButtonToChiaki() {
        let mapper = ControllerInputMapper()
        
        #expect(mapper.map(.cross) == .cross)
        #expect(mapper.map(.circle) == .moon)
        #expect(mapper.map(.square) == .box)
        #expect(mapper.map(.triangle) == .pyramid)
    }
}
