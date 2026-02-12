// SPDX-License-Identifier: AGPL-3.0-only
//
//  DiscoveryLifecycleTests.swift
//  ChiakiTests
//
//  Tests for host discovery lifecycle (T-192, T-194)
//
//  @requirement F-032 - 自动发现主机
//  @verifies AC-111, AC-112
//

import Testing
import Foundation
@testable import Chiaki

@MainActor
struct DiscoveryLifecycleTests {

    /**
     * @verifies AC-111 - 自动启动发现
     * @testcase UT-049.1
     */
    @Test func testStartDiscoveryIfNeeded() async {
        let viewModel = HostListViewModel()
        viewModel.initializeIfNeeded()
        
        let initialDiscoveringState = viewModel.isDiscovering
        
        viewModel.startDiscoveryIfNeeded()
        #expect(viewModel.isDiscovering || initialDiscoveringState)
        
        // Should not crash or change state if called again
        viewModel.startDiscoveryIfNeeded()
        #expect(viewModel.isDiscovering)
        
        viewModel.stopDiscovery()
    }

    /**
     * @verifies AC-112 - 自动停止发现
     * @testcase UT-049.2
     */
    @Test func testStopDiscoveryIfNeeded() async {
        let viewModel = HostListViewModel()
        viewModel.initializeIfNeeded()
        
        viewModel.startDiscovery()
        #expect(viewModel.isDiscovering)
        
        viewModel.stopDiscoveryIfNeeded()
        #expect(!viewModel.isDiscovering)
        
        // Should not crash or change state if called again
        viewModel.stopDiscoveryIfNeeded()
        #expect(!viewModel.isDiscovering)
    }
    
    /**
     * @verifies AC-114 - 保留下拉刷新
     * @testcase UT-049.3
     */
    @Test func testRefreshStillWorks() async {
        let viewModel = HostListViewModel()
        viewModel.initializeIfNeeded()
        
        await viewModel.refresh()
        #expect(viewModel.isDiscovering)
        
        viewModel.stopDiscovery()
    }
}
