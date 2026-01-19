// SPDX-License-Identifier: AGPL-3.0-only
//
// Platform+SwiftUI.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// Platform-specific SwiftUI typealiases
//

import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
public typealias ViewRepresentable = UIViewRepresentable
public typealias NativeView = UIView
#elseif os(macOS)
import AppKit
public typealias ViewRepresentable = NSViewRepresentable
public typealias NativeView = NSView
#endif
