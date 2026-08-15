import SwiftUI
import WebKit

struct NomadGlobeView: UIViewRepresentable {
    let showLabels: Bool
    let visits: [TravelVisit]

    init(showLabels: Bool = false, visits: [TravelVisit] = []) {
        self.showLabels = showLabels
        self.visits = visits
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showLabels: showLabels, visits: visits)
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
        context.coordinator.visits = visits
        let value = showLabels ? "true" : "false"
        webView.evaluateJavaScript("window.setPlaceTagsVisible && window.setPlaceTagsVisible(\(value));")
        if let data = try? JSONEncoder().encode(visits),
           let json = String(data: data, encoding: .utf8) {
            webView.evaluateJavaScript("window.setVisits && window.setVisits(\(json));")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var showLabels: Bool
        var visits: [TravelVisit]

        init(showLabels: Bool, visits: [TravelVisit]) {
            self.showLabels = showLabels
            self.visits = visits
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let value = showLabels ? "true" : "false"
            webView.evaluateJavaScript("window.setPlaceTagsVisible && window.setPlaceTagsVisible(\(value));")
            if let data = try? JSONEncoder().encode(visits),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("window.setVisits && window.setVisits(\(json));")
            }
        }
    }
}
