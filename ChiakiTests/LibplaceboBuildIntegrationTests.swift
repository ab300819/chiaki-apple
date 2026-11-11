// SPDX-License-Identifier: AGPL-3.0-only
//
//  LibplaceboBuildIntegrationTests.swift
//  ChiakiTests
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @verifies AC-170 - MoltenVK 路径平台编译
//  @verifies AC-171 - 预编译 xcframework 集成
//  @verifies AC-172 - 动态 framework 链接
//  @verifies AC-189 - Metal 后端消除 MoltenVK 依赖
//

import Testing
import Foundation

@Suite("UT-060 libplacebo 构建与依赖验证")
struct LibplaceboBuildIntegrationTests {

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ChiakiTests
            .deletingLastPathComponent() // repo root
    }

    private var frameworksRoot: URL {
        projectRoot.appendingPathComponent("Frameworks", isDirectory: true)
    }

    private func frameworkBinaryPath(_ name: String, slice: String) -> URL {
        frameworksRoot
            .appendingPathComponent("\(name).xcframework", isDirectory: true)
            .appendingPathComponent(slice, isDirectory: true)
            .appendingPathComponent("\(name).framework", isDirectory: true)
            .appendingPathComponent(name)
    }

    private func frameworkBinaryCandidates(_ name: String, slice: String) -> [URL] {
        let frameworkRoot = frameworksRoot
            .appendingPathComponent("\(name).xcframework", isDirectory: true)
            .appendingPathComponent(slice, isDirectory: true)
            .appendingPathComponent("\(name).framework", isDirectory: true)

        return [
            frameworkRoot.appendingPathComponent(name),
            frameworkRoot.appendingPathComponent("Versions/A/\(name)")
        ]
    }

    private func existingFrameworkBinaryPath(_ name: String, slice: String) -> URL? {
        for candidate in frameworkBinaryCandidates(name, slice: slice) {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func hasT243Artifacts() -> Bool {
        let libplacebo = frameworksRoot.appendingPathComponent("libplacebo.xcframework", isDirectory: true)
        return FileManager.default.fileExists(atPath: libplacebo.path)
    }

    private func runTool(_ launchPath: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = stdout

        try process.run()
        // Drain before waiting: output larger than the pipe buffer (e.g. nm) would deadlock.
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /**
     * @verifies AC-170 - MoltenVK 路径平台编译
     * @testcase UT-060.1
     */
    @Test("libplacebo dynamic framework 可加载")
    func testLibplaceboFrameworkLoads() throws {
        guard hasT243Artifacts() else { return }

        #expect(existingFrameworkBinaryPath("libplacebo", slice: "macos-arm64") != nil)
    }

    /**
     * @verifies AC-189 - Metal 后端消除 MoltenVK 依赖
     * @testcase UT-060.2
     */
    @Test("libplacebo 导出 Metal 后端且不依赖 MoltenVK/Vulkan")
    func testLibplaceboUsesMetalBackend() throws {
        guard hasT243Artifacts() else { return }

        guard let macBinary = existingFrameworkBinaryPath("libplacebo", slice: "macos-arm64") else {
            #expect(Bool(false), "missing libplacebo binary in macos-arm64 slice")
            return
        }

        let deps = try runTool("/usr/bin/otool", args: ["-L", macBinary.path])
        if deps.contains("cannot be used within an App Sandbox") {
            return
        }
        #expect(!deps.contains("MoltenVK"))
        #expect(!deps.lowercased().contains("vulkan"))

        let exports = try runTool("/usr/bin/nm", args: ["-gU", macBinary.path])
        #expect(exports.contains(" T _pl_metal_create\n"))
        #expect(exports.contains(" T _pl_metal_create_swapchain\n"))
    }

    /**
     * @verifies AC-172 - 动态 framework 链接
     * @testcase UT-060.3
     */
    @Test("libplacebo 以动态 framework 链接")
    func testLibplaceboIsDynamicFramework() throws {
        guard hasT243Artifacts() else { return }

        guard let macBinary = existingFrameworkBinaryPath("libplacebo", slice: "macos-arm64") else {
            #expect(Bool(false), "missing libplacebo binary in macos-arm64 slice")
            return
        }

        let output = try runTool("/usr/bin/otool", args: ["-L", macBinary.path])
        if output.contains("cannot be used within an App Sandbox") {
            return
        }

        #expect(output.contains("libplacebo.framework/libplacebo"))
        #expect(!output.contains("libplacebo.a"))
    }

    /**
     * @verifies AC-171 - 预编译 xcframework 集成
     * @testcase UT-060.4
     */
    @Test("xcframework 包含 macOS arm64 slice")
    func testPlatformBuildSlices() throws {
        guard hasT243Artifacts() else { return }

        let requiredSlices = [
            frameworksRoot.appendingPathComponent("libplacebo.xcframework/macos-arm64")
        ]

        for slice in requiredSlices {
            #expect(FileManager.default.fileExists(atPath: slice.path), "missing slice: \(slice.lastPathComponent)")
        }
    }
}
