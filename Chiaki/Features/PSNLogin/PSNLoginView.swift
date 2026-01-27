// SPDX-License-Identifier: AGPL-3.0-only
//
// PSNLoginView.swift
// Chiaki - PlayStation Remote Play Client for Apple Platforms
//
// WebView for PSN OAuth login

import SwiftUI
import WebKit

struct PSNLoginView: View {
    @Environment(\.dismiss) var dismiss
    @State private var service = PSNService.shared
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            ZStack {
                WebView(url: service.getLoginUrl()) { code in
                    Task {
                        do {
                            try await service.handleAuthorizationCode(code)
                            dismiss()
                        } catch {
                            self.error = error
                        }
                    }
                }
                .navigationTitle(L10n.PSNLogin.title)
                #if os(iOS) || os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.Common.cancel) {
                            dismiss()
                        }
                    }
                }

                if service.isAuthenticating {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 12) {
                            ProgressView()
                            Text(L10n.PSNLogin.authenticating)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
            .alert(L10n.PSNLogin.authFailed, isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button(L10n.Common.ok) { error = nil }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}

struct WebView: ViewRepresentable {
    let url: URL
    let onCodeIntercepted: (String) -> Void
    
    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #endif
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeIntercepted: onCodeIntercepted)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onCodeIntercepted: (String) -> Void
        
        init(onCodeIntercepted: @escaping (String) -> Void) {
            self.onCodeIntercepted = onCodeIntercepted
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.absoluteString.starts(with: "com.playstation.PlayStationApp://redirect") {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                        onCodeIntercepted(code)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}

#Preview {
    PSNLoginView()
        .environment(SettingsStore())
        .environment(NavigationManager())
}
