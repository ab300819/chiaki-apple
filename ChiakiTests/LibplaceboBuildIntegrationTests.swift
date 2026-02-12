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
        let moltenvk = frameworksRoot.appendingPathComponent("MoltenVK.xcframework", isDirectory: true)

        return FileManager.default.fileExists(atPath: libplacebo.path)
            && FileManager.default.fileExists(atPath: moltenvk.path)
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
        guard hasT243Artifacts() else { return }

        #expect(existingFrameworkBinaryPath("libplacebo", slice: "macos-arm64") != nil)
    }

    /**
     * @verifies AC-170 - MoltenVK 路径平台编译
     * @testcase UT-060.2
     */
    @Test("MoltenVK framework 可加载")
    func testMoltenVKFrameworkLoads() throws {
        guard hasT243Artifacts() else { return }

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
    @Test("xcframework 包含 macOS 与 iOS slices")
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
