import SwiftUI
import WebKit

struct YouTubePlayerView: NSViewRepresentable {
    let videoId: String
    @State private var isLoading = true
    @State private var hasError = false
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
        loadVideo(in: webView)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadVideo(in: webView)
    }
    
    private func loadVideo(in webView: WKWebView) {
        let embedHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { margin: 0; background-color: black; }
                    .video-container {
                        position: relative;
                        width: 100%;
                        height: 100vh;
                        background: black;
                    }
                    .video-container iframe {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        border: 0;
                    }
                </style>
            </head>
            <body>
                <div class="video-container">
                    <iframe src="https://www.youtube.com/embed/\(videoId)?rel=0&showinfo=0&playsinline=1&enablejsapi=1&origin=http://localhost&hl=pt&cc_lang_pref=pt&cc_load_policy=1&modestbranding=1&iv_load_policy=3"
                            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                            allowfullscreen>
                    </iframe>
                </div>
                <script>
                    document.body.style.backgroundColor = 'black';
                    document.documentElement.style.backgroundColor = 'black';
                </script>
            </body>
            </html>
        """
        
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("""
                document.body.style.backgroundColor = 'black';
                document.documentElement.style.backgroundColor = 'black';
            """)
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.hasError = true
        }
    }
} 