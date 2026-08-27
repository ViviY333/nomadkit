import SwiftUI
import WebKit

enum NomadGlobeLabelMode: String {
    case none, cities, countries, days
}

/// A local globe.gl surface used for the richer, star-field map treatment.
/// Keeping the bundle local makes this safe to use in a WKWebView without a CDN.
struct NomadGlobeGLView: UIViewRepresentable {
    let showLabels: Bool
    let visits: [TravelVisit]
    let localeIdentifier: String
    let labelMode: NomadGlobeLabelMode

    init(
        showLabels: Bool,
        visits: [TravelVisit],
        localeIdentifier: String = Locale.current.identifier,
        labelMode: NomadGlobeLabelMode = .none
    ) {
        self.showLabels = showLabels
        self.visits = visits
        self.localeIdentifier = localeIdentifier
        self.labelMode = labelMode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showLabels: showLabels, visits: visits, localeIdentifier: localeIdentifier, labelMode: labelMode)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "nomad-globe-gl", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.showLabels = showLabels
        context.coordinator.visits = visits
        context.coordinator.localeIdentifier = localeIdentifier
        context.coordinator.labelMode = labelMode
        context.coordinator.pushState(to: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var showLabels: Bool
        var visits: [TravelVisit]
        var localeIdentifier: String
        var labelMode: NomadGlobeLabelMode

        init(showLabels: Bool, visits: [TravelVisit], localeIdentifier: String, labelMode: NomadGlobeLabelMode) {
            self.showLabels = showLabels
            self.visits = visits
            self.localeIdentifier = localeIdentifier
            self.labelMode = labelMode
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pushState(to: webView)
        }

        func pushState(to webView: WKWebView) {
            let labels = showLabels ? "true" : "false"
            webView.evaluateJavaScript("window.setGlobeLabels && window.setGlobeLabels(\(labels));")
            guard let localeData = try? JSONEncoder().encode(localeIdentifier),
                  let localeJSON = String(data: localeData, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.setGlobeLocale && window.setGlobeLocale(\(localeJSON));")
            webView.evaluateJavaScript("window.setGlobeLabelMode && window.setGlobeLabelMode('\(labelMode.rawValue)');")
            guard let data = try? JSONEncoder().encode(visits),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.setGlobeVisits && window.setGlobeVisits(\(json));")
        }
    }
}
