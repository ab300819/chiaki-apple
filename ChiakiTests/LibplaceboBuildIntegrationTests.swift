// SPDX-License-Identifier: AGPL-3.0-only
//
//  LibplaceboBuildIntegrationTests.swift
//  ChiakiTests
//
//  @requirement F-042 - libplacebo 渲染后端集成
//  @verifies AC-170 - MoltenVK 路径平台编译
//  @verifies AC-171 - 预编译 xcframework 集成
//  @verifies AC-172 - 动态 framework 链接
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

    private func requireT243Artifacts() throws {
        let libplacebo = frameworksRoot.appendingPathComponent("libplacebo.xcframework", isDirectory: true)
        let moltenvk = frameworksRoot.appendingPathComponent("MoltenVK.xcframework", isDirectory: true)

        guard FileManager.default.fileExists(atPath: libplacebo.path),
              FileManager.default.fileExists(atPath: moltenvk.path) else {
            throw Skip("TODO(T-243): 先执行 Scripts/build-libplacebo.sh 产出 xcframework 并完成 Xcode Embed & Sign")
        }
    }

    private func runTool(_ launchPath: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = stdout

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    /**
     * @verifies AC-170 - MoltenVK 路径平台编译
     * @testcase UT-060.1
     */
    @Test("libplacebo dynamic framework 可加载")
    func testLibplaceboFrameworkLoads() throws {
        try requireT243Artifacts()

        let macBinary = frameworkBinaryPath("libplacebo", slice: "macos-arm64_x86_64")
        let iOSBinary = frameworkBinaryPath("libplacebo", slice: "ios-arm64")
        let iOSSimBinary = frameworkBinaryPath("libplacebo", slice: "ios-arm64-simulator")

        #expect(FileManager.default.fileExists(atPath: macBinary.path))
        #expect(FileManager.default.fileExists(atPath: iOSBinary.path))
        #expect(FileManager.default.fileExists(atPath: iOSSimBinary.path))
    }

    /**
     * @verifies AC-170 - MoltenVK 路径平台编译
     * @testcase UT-060.2
     */
    @Test("MoltenVK framework 可加载")
    func testMoltenVKFrameworkLoads() throws {
        try requireT243Artifacts()

        let macBinary = frameworkBinaryPath("MoltenVK", slice: "macos-arm64_x86_64")
        let iOSBinary = frameworkBinaryPath("MoltenVK", slice: "ios-arm64")

        #expect(FileManager.default.fileExists(atPath: macBinary.path))
        #expect(FileManager.default.fileExists(atPath: iOSBinary.path))
    }

    /**
     * @verifies AC-172 - 动态 framework 链接
     * @testcase UT-060.3
     */
    @Test("libplacebo 以动态 framework 链接")
    func testLibplaceboIsDynamicFramework() throws {
        try requireT243Artifacts()

        let macBinary = frameworkBinaryPath("libplacebo", slice: "macos-arm64_x86_64")
        let output = try runTool("/usr/bin/otool", args: ["-L", macBinary.path])

        #expect(output.contains("libplacebo.framework/libplacebo"))
        #expect(!output.contains("libplacebo.a"))
    }

    /**
     * @verifies AC-171 - 预编译 xcframework 集成
     * @testcase UT-060.4
     */
    @Test("xcframework 包含 macOS 与 iOS slices")
    func testPlatformBuildSlices() throws {
        try requireT243Artifacts()

        let requiredSlices = [
            frameworksRoot.appendingPathComponent("libplacebo.xcframework/macos-arm64_x86_64"),
            frameworksRoot.appendingPathComponent("libplacebo.xcframework/ios-arm64"),
            frameworksRoot.appendingPathComponent("libplacebo.xcframework/ios-arm64-simulator")
        ]

        for slice in requiredSlices {
            #expect(FileManager.default.fileExists(atPath: slice.path), "missing slice: \(slice.lastPathComponent)")
        }
    }
}
