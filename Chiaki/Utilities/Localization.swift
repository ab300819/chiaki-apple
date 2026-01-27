// SPDX-License-Identifier: AGPL-3.0-only
//
// Localization.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Localization utilities and String extension

import Foundation

// MARK: - Localized String Keys

/// Namespace for all localization keys
enum L10n {
    // MARK: - Common

    enum Common {
        static let cancel = String(localized: "common.cancel")
        static let save = String(localized: "common.save")
        static let delete = String(localized: "common.delete")
        static let done = String(localized: "common.done")
        static let ok = String(localized: "common.ok")
        static let hide = String(localized: "common.hide")
        static let unhide = String(localized: "common.unhide")
        static let online = String(localized: "common.online")
        static let offline = String(localized: "common.offline")
        static let standby = String(localized: "common.standby")
    }

    // MARK: - Navigation

    enum Nav {
        static let hosts = String(localized: "nav.hosts")
        static let settings = String(localized: "nav.settings")
        static let general = String(localized: "nav.general")
        static let video = String(localized: "nav.video")
        static let audio = String(localized: "nav.audio")
        static let controller = String(localized: "nav.controller")
        static let keyboard = String(localized: "nav.keyboard")
        static let account = String(localized: "nav.account")
        static let consoles = String(localized: "nav.consoles")
        static let logs = String(localized: "nav.logs")
        static let data = String(localized: "nav.data")
    }

    // MARK: - Host List

    enum HostList {
        static let title = String(localized: "hostList.title")
        static let addHost = String(localized: "hostList.addHost")
        static let noHostsFound = String(localized: "hostList.noHostsFound")
        static let noHostsDescription = String(localized: "hostList.noHostsDescription")
        static let deleteConfirmTitle = String(localized: "hostList.deleteConfirmTitle")
        static let deleteConfirmMessage = String(localized: "hostList.deleteConfirmMessage")
        static let wakeUp = String(localized: "hostList.wakeUp")
        static let registerNeeded = String(localized: "hostList.registerNeeded")
        static func lastSeen(_ date: String) -> String {
            String(localized: "hostList.lastSeen \(date)")
        }
        static let discover = String(localized: "hostList.discover")
        static let stop = String(localized: "hostList.stop")
        static let stopDiscovery = String(localized: "hostList.stopDiscovery")
        static let startDiscovery = String(localized: "hostList.startDiscovery")
    }

    // MARK: - Streaming

    enum Streaming {
        static let controls = String(localized: "streaming.controls")
        static let connecting = String(localized: "streaming.connecting")
        static let reconnecting = String(localized: "streaming.reconnecting")
        static let videoPlaceholder = String(localized: "streaming.videoPlaceholder")
        static let disconnectConfirmTitle = String(localized: "streaming.disconnectConfirmTitle")
        static let disconnectConfirmMessage = String(localized: "streaming.disconnectConfirmMessage")
        static let disconnectOnly = String(localized: "streaming.disconnectOnly")
        static let restModeAndDisconnect = String(localized: "streaming.restModeAndDisconnect")
        static let disconnect = String(localized: "streaming.disconnect")
        static let restMode = String(localized: "streaming.restMode")
    }

    // MARK: - Streaming Controls

    enum StreamingControls {
        static let audio = String(localized: "streamingControls.audio")
        static let volume = String(localized: "streamingControls.volume")
        static let displayMode = String(localized: "streamingControls.displayMode")
        static let videoPreset = String(localized: "streamingControls.videoPreset")
        static let quickActions = String(localized: "streamingControls.quickActions")
        static let zoomLevel = String(localized: "streamingControls.zoomLevel")
        static let micMuted = String(localized: "streamingControls.micMuted")
        static let micActive = String(localized: "streamingControls.micActive")
    }

    // MARK: - Settings

    enum Settings {
        enum General {
            static let autoConnect = String(localized: "settings.general.autoConnect")
            static let autoConnectOnLaunch = String(localized: "settings.general.autoConnectOnLaunch")
            static let autoConnectDescription = String(localized: "settings.general.autoConnectDescription")
            static let targetConsole = String(localized: "settings.general.targetConsole")
            static let lastConnected = String(localized: "settings.general.lastConnected")
            static let wakeConsole = String(localized: "settings.general.wakeConsole")
            static let sessionActions = String(localized: "settings.general.sessionActions")
            static let sessionActionsDescription = String(localized: "settings.general.sessionActionsDescription")
            static let onDisconnect = String(localized: "settings.general.onDisconnect")
            static let onAppSuspend = String(localized: "settings.general.onAppSuspend")
            static let privacy = String(localized: "settings.general.privacy")
            static let streamerMode = String(localized: "settings.general.streamerMode")
            static let streamerModeDescription = String(localized: "settings.general.streamerModeDescription")
        }

        enum Video {
            static let profile = String(localized: "settings.video.profile")
            static let local = String(localized: "settings.video.local")
            static let remote = String(localized: "settings.video.remote")
            static let resolution = String(localized: "settings.video.resolution")
            static let frameRate = String(localized: "settings.video.frameRate")
            static let bitrate = String(localized: "settings.video.bitrate")
            static let hdr = String(localized: "settings.video.hdr")
            static let quality = String(localized: "settings.video.quality")
            static let hdrFineTuning = String(localized: "settings.video.hdrFineTuning")
            static let hdrDescription = String(localized: "settings.video.hdrDescription")
            static let advanced = String(localized: "settings.video.advanced")
            static let scaling = String(localized: "settings.video.scaling")
        }

        enum Audio {
            static let volume = String(localized: "settings.audio.volume")
            static let outputInput = String(localized: "settings.audio.outputInput")
            static let microphone = String(localized: "settings.audio.microphone")
        }

        enum Controller {
            static let connectedControllers = String(localized: "settings.controller.connectedControllers")
            static let noControllers = String(localized: "settings.controller.noControllers")
            static let feedback = String(localized: "settings.controller.feedback")
            static let feedbackDescription = String(localized: "settings.controller.feedbackDescription")
            static let input = String(localized: "settings.controller.input")
        }

        enum Consoles {
            static let title = String(localized: "settings.consoles.title")
            static let registeredConsoles = String(localized: "settings.consoles.registeredConsoles")
            static let registeredDescription = String(localized: "settings.consoles.registeredDescription")
            static let hiddenConsoles = String(localized: "settings.consoles.hiddenConsoles")
            static let hiddenDescription = String(localized: "settings.consoles.hiddenDescription")
            static let noRegistered = String(localized: "settings.consoles.noRegistered")
        }

        enum Data {
            static let exportSettings = String(localized: "settings.data.exportSettings")
            static let importSettings = String(localized: "settings.data.importSettings")
            static let resetToDefaults = String(localized: "settings.data.resetToDefaults")
            static let resetTitle = String(localized: "settings.data.resetTitle")
            static let resetMessage = String(localized: "settings.data.resetMessage")
        }

        enum Logs {
            static let title = String(localized: "settings.logs.title")
            static let export = String(localized: "settings.logs.export")
            static let allLevels = String(localized: "settings.logs.allLevels")
            static let levelFilter = String(localized: "settings.logs.levelFilter")
            static let searchPrompt = String(localized: "settings.logs.searchPrompt")
            static let exportHeader = String(localized: "settings.logs.exportHeader")
            static let exportGenerated = String(localized: "settings.logs.exportGenerated")
            static let exportTotalEntries = String(localized: "settings.logs.exportTotalEntries")
        }

        enum Keyboard {
            static let title = String(localized: "settings.keyboard.title")
            static let enableKeyboardInput = String(localized: "settings.keyboard.enableKeyboardInput")
            static let enableDescription = String(localized: "settings.keyboard.enableDescription")
            static let notAssigned = String(localized: "settings.keyboard.notAssigned")
            static let clearMapping = String(localized: "settings.keyboard.clearMapping")
            static let pressKey = String(localized: "settings.keyboard.pressKey")
            static let pressKeyDescription = String(localized: "settings.keyboard.pressKeyDescription")
            static let resetToDefaults = String(localized: "settings.keyboard.resetToDefaults")
        }
    }

    // MARK: - Log Levels

    enum LogLevel {
        static let error = String(localized: "logLevel.error")
        static let warning = String(localized: "logLevel.warning")
        static let info = String(localized: "logLevel.info")
        static let debug = String(localized: "logLevel.debug")
        static let verbose = String(localized: "logLevel.verbose")
    }

    // MARK: - Accessibility

    enum Accessibility {
        static let disconnectStream = String(localized: "accessibility.disconnectStream")
        static let openControlsMenu = String(localized: "accessibility.openControlsMenu")
        static func networkQuality(_ quality: String) -> String {
            String(localized: "accessibility.networkQuality \(quality)")
        }
        static func packetLossStats(loss: Double, dropped: Int, recovered: Int) -> String {
            String(localized: "accessibility.packetLossStats \(loss) \(dropped) \(recovered)")
        }
    }

    // MARK: - PSN Login

    enum PSNLogin {
        static let title = String(localized: "psnLogin.title")
        static let authenticating = String(localized: "psnLogin.authenticating")
        static let authFailed = String(localized: "psnLogin.authFailed")
    }

    // MARK: - Errors

    enum Error {
        static let hostNotRegistered = String(localized: "error.hostNotRegistered")
        static let connectionFailed = String(localized: "error.connectionFailed")
        static let unableToAccessFile = String(localized: "error.unableToAccessFile")
        static func exportFailed(_ message: String) -> String {
            String(localized: "error.exportFailed \(message)")
        }
        static func importFailed(_ message: String) -> String {
            String(localized: "error.importFailed \(message)")
        }
    }
}
