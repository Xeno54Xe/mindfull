import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';

class SpotifyAuthScreen extends StatefulWidget {
  const SpotifyAuthScreen({super.key});

  @override
  State<SpotifyAuthScreen> createState() => _SpotifyAuthScreenState();
}

class _SpotifyAuthScreenState extends State<SpotifyAuthScreen> {
  late final WebViewController _controller;
  
  // YOUR CONFIGURATION
  final String clientId = "d392c7212c464db4b1fb4f2fcb77bb95"; 
  final String redirectUri = "http://localhost:8080/callback"; // Arbitrary, we intercept it
  final String scope = "user-top-read"; // We only need to read top artists

  @override
  void initState() {
    super.initState();
    
    // Build the Spotify Authorize URL
    final String authUrl = "https://accounts.spotify.com/authorize"
        "?client_id=$clientId"
        "&response_type=token" // Implicit Grant (Returns token directly)
        "&redirect_uri=$redirectUri"
        "&scope=$scope";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // LISTENER: Check if the URL contains our Redirect URI
            if (request.url.startsWith(redirectUri)) {
              // Extract the token from the URL fragment (#access_token=...)
              if (request.url.contains("access_token=")) {
                final uri = Uri.parse(request.url.replaceFirst('#', '?')); // Parse as query param
                final token = uri.queryParameters['access_token'];
                
                if (token != null) {
                  _saveToken(token);
                }
              }
              return NavigationDecision.prevent; // Stop loading the dummy page
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_token', token);
    // Also save a timestamp to check expiry later if needed
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Spotify Connected Successfully! 🎵"), backgroundColor: Color(0xFF1DB954)),
      );
      Navigator.pop(context, true); // Return success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect Spotify", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}