import SwiftUI
import WebKit

struct NomadGlobeView: UIViewRepresentable {
    let showLabels: Bool
    let visitedCountryCodes: [String]

    init(showLabels: Bool = false, visitedCountryCodes: [String] = []) {
        self.showLabels = showLabels
        self.visitedCountryCodes = visitedCountryCodes
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showLabels: showLabels, visitedCountryCodes: visitedCountryCodes)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "nomad-globe", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.showLabels = showLabels
        context.coordinator.visitedCountryCodes = visitedCountryCodes
        let value = showLabels ? "true" : "false"
        webView.evaluateJavaScript("window.setPlaceTagsVisible && window.setPlaceTagsVisible(\(value));")
        if let data = try? JSONEncoder().encode(visitedCountryCodes),
           let json = String(data: data, encoding: .utf8) {
            webView.evaluateJavaScript("window.setVisitedCountries && window.setVisitedCountries(\(json));")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var showLabels: Bool
        var visitedCountryCodes: [String]

        init(showLabels: Bool, visitedCountryCodes: [String]) {
            self.showLabels = showLabels
            self.visitedCountryCodes = visitedCountryCodes
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let value = showLabels ? "true" : "false"
            webView.evaluateJavaScript("window.setPlaceTagsVisible && window.setPlaceTagsVisible(\(value));")
            if let data = try? JSONEncoder().encode(visitedCountryCodes),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("window.setVisitedCountries && window.setVisitedCountries(\(json));")
            }
        }
    }
}
