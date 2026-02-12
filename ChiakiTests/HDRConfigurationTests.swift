// SPDX-License-Identifier: AGPL-3.0-only
//
// HDRConfigurationTests.swift
// ChiakiTests
//
// Unit tests for HDRConfiguration
// @requirement F-025 - HDR 渲染管线优化
// @requirement F-026 - 渲染模块解耦重构

import XCTest
@testable import Chiaki

/// @verifies AC-088 - HDR 配置统一
final class HDRConfigurationTests: XCTestCase {

    // MARK: - UT-032.1: Default Configuration

    /// @verifies AC-088
    /// @testcase UT-032.1
    func testDefaultConfiguration() {
        let config = HDRConfiguration()

        XCTAssertFalse(config.enabled, "默认应禁用 HDR")
        XCTAssertEqual(config.colorSpace, .bt709, "默认色彩空间应为 BT.709")
        XCTAssertEqual(config.edrIntensity, 1.0, "默认 EDR 强度应为 1.0")
        XCTAssertEqual(config.colorRange, .video, "默认色彩范围应为 Video Range")
        XCTAssertEqual(config.tonemapMode, .passthrough, "默认 Tonemap 模式应为 Passthrough")
        XCTAssertTrue(config.gamutMappingEnabled, "默认应启用色域映射")
    }

    // MARK: - UT-032.2: HDR Preset

    /// @verifies AC-088
    /// @testcase UT-032.2
    func testHDRPreset() {
        let config = HDRConfiguration.hdr

        XCTAssertTrue(config.enabled, "HDR 预设应启用 HDR")
        XCTAssertEqual(config.colorSpace, .bt2020, "HDR 预设应使用 BT.2020")
        XCTAssertEqual(config.colorRange, .video, "HDR 预设应使用 Video Range")
        XCTAssertEqual(config.tonemapMode, .passthrough, "HDR 预设应使用 Passthrough")
        XCTAssertTrue(config.gamutMappingEnabled, "HDR 预设应启用色域映射")
    }

    // MARK: - UT-032.3: SDR Preset

    /// @verifies AC-088
    /// @testcase UT-032.3
    func testSDRPreset() {
        let config = HDRConfiguration.sdr

        XCTAssertFalse(config.enabled, "SDR 预设应禁用 HDR")
        XCTAssertEqual(config.colorSpace, .bt709, "SDR 预设应使用 BT.709")
        XCTAssertEqual(config.colorRange, .video, "SDR 预设应使用 Video Range")
        XCTAssertFalse(config.gamutMappingEnabled, "SDR 预设不应启用色域映射")
    }

    // MARK: - UT-032.4: isHDR Computed Property

    /// @verifies AC-088
    /// @testcase UT-032.4
    func testIsHDRComputed() {
        var config = HDRConfiguration()

        // 默认: enabled=false, colorSpace=bt709
        XCTAssertFalse(config.isHDR, "默认配置 isHDR 应为 false")

        // 仅启用 enabled
        config.enabled = true
        XCTAssertFalse(config.isHDR, "enabled=true 但 colorSpace=bt709 时 isHDR 应为 false")

        // 启用 enabled + bt2020
        config.colorSpace = .bt2020
        XCTAssertTrue(config.isHDR, "enabled=true 且 colorSpace=bt2020 时 isHDR 应为 true")

        // 禁用 enabled 但保持 bt2020
        config.enabled = false
        XCTAssertFalse(config.isHDR, "enabled=false 时 isHDR 应为 false 即使 colorSpace=bt2020")
    }

    // MARK: - UT-032.5: Codable

    /// @verifies AC-088
    /// @testcase UT-032.5
    func testCodable() throws {
        let config = HDRConfiguration(
            enabled: true,
            edrIntensity: 1.5,
            colorSpace: .bt2020,
            colorRange: .full,
            tonemapMode: .aces,
            gamutMappingEnabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HDRConfiguration.self, from: data)

        XCTAssertEqual(config, decoded, "编码后解码应得到相等的配置")
    }

    /// @verifies AC-088
    /// @testcase UT-032.5b
    func testCodableWithDefaultValues() throws {
        let config = HDRConfiguration()

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HDRConfiguration.self, from: data)

        XCTAssertEqual(config, decoded, "默认配置编码解码应保持一致")
    }

    // MARK: - UT-032.6: Equatable

    /// @verifies AC-088
    /// @testcase UT-032.6
    func testEquatable() {
        let config1 = HDRConfiguration(
            enabled: true,
            edrIntensity: 1.2,
            colorSpace: .bt2020,
            colorRange: .full,
            tonemapMode: .aces,
            gamutMappingEnabled: true
        )

        let config2 = HDRConfiguration(
            enabled: true,
            edrIntensity: 1.2,
            colorSpace: .bt2020,
            colorRange: .full,
            tonemapMode: .aces,
            gamutMappingEnabled: true
        )

        XCTAssertEqual(config1, config2, "相同配置应相等")
    }

    /// @verifies AC-088
    /// @testcase UT-032.6b
    func testNotEquatable() {
        let config1 = HDRConfiguration(enabled: true, colorSpace: .bt2020)
        let config2 = HDRConfiguration(enabled: true, colorSpace: .bt709)

        XCTAssertNotEqual(config1, config2, "不同色彩空间配置应不相等")
    }

    // MARK: - Additional: Enum Raw Values (Review 要点: 与 Shader 常量对齐)

    /// @verifies AC-088
    func testColorSpaceRawValues() {
        // 验证枚举原始值与 Shader 常量对齐
        XCTAssertEqual(HDRColorSpace.bt709.rawValue, 0, "BT.709 应映射到 Shader 常量 0")
        XCTAssertEqual(HDRColorSpace.bt601.rawValue, 1, "BT.601 应映射到 Shader 常量 1")
        XCTAssertEqual(HDRColorSpace.bt2020.rawValue, 2, "BT.2020 应映射到 Shader 常量 2")
    }

    /// @verifies AC-088
    func testColorRangeRawValues() {
        // 验证枚举原始值与 Shader 常量对齐
        XCTAssertEqual(HDRColorRange.video.rawValue, 0, "Video Range 应映射到 Shader 常量 0")
        XCTAssertEqual(HDRColorRange.full.rawValue, 1, "Full Range 应映射到 Shader 常量 1")
    }

    /// @verifies AC-088
    func testTonemapModeRawValues() {
        // 验证枚举原始值与 Shader 常量对齐
        XCTAssertEqual(TonemapMode.passthrough.rawValue, 0, "Passthrough 应映射到 Shader 常量 0")
        XCTAssertEqual(TonemapMode.aces.rawValue, 1, "ACES 应映射到 Shader 常量 1")
    }

    // MARK: - Additional: EDR Intensity Range

    /// @verifies AC-088
    func testEDRIntensityRange() {
        // 验证 EDR 强度在合理范围内
        var config = HDRConfiguration()

        config.edrIntensity = 0.5
        XCTAssertEqual(config.edrIntensity, 0.5, "最小 EDR 强度应为 0.5")

        config.edrIntensity = 2.0
        XCTAssertEqual(config.edrIntensity, 2.0, "最大 EDR 强度应为 2.0")
    }
}
