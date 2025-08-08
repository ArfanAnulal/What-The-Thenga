import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather/weather.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

// Enum to manage different UI states cleanly
enum UIState { initial, loading, danger, safe, whatTheThenga, error }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  UIState _currentState = UIState.initial;
  String _errorMessage = '';

  // --- Image Picker Logic ---
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);

    if (image != null) {
      _uploadImage(File(image.path));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Library'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- API and Weather Logic ---
  Future<void> _uploadImage(File image) async {
    setState(() => _currentState = UIState.loading);

    String fileName = image.path.split('/').last;
    FormData formData = FormData.fromMap({
      "picture": await MultipartFile.fromFile(image.path, filename: fileName),
    });

    try {
      // **Replace with your actual API endpoint**
      // var response = await Dio().post('YOUR_BACKEND_API_URL', data: formData);

      // --- MOCK RESPONSE FOR TESTING ---
      await Future.delayed(const Duration(seconds: 2));
      // Simulate a positive score
      var mockScore = 0.8; 
      // var mockScore = 0.2; // Simulate a negative score
      // --- END MOCK RESPONSE ---

      // if (response.statusCode == 200) {
      //   var score = response.data['score'];
      if (mockScore > 0.5) { // Positive score threshold
        _getWeather();
      } else {
        setState(() => _currentState = UIState.whatTheThenga);
      }
      // } else {
      //   _handleError("Could not connect to the server.");
      // }
    } catch (e) {
      _handleError("Something went wrong during upload.");
    }
  }

  Future<void> _getWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _handleError("Location permissions are denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // **Replace with your actual Weather API key**
      WeatherFactory wf = WeatherFactory("YOUR_WEATHER_API_KEY");
      Weather w = await wf.currentWeatherByLocation(position.latitude, position.longitude);
      
      // Using a low threshold for testing purposes
      if (w.windSpeed != null && w.windSpeed! > 2) { // Wind speed threshold
        setState(() => _currentState = UIState.danger);
      } else {
        setState(() => _currentState = UIState.safe);
      }
    } catch (e) {
      _handleError("Could not get location or weather data.");
    }
  }

  void _handleError(String message) {
    setState(() {
      _currentState = UIState.error;
      _errorMessage = message;
    });
  }

  void _resetState() {
    setState(() => _currentState = UIState.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        // Fun gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Falling coconut animation for the 'danger' state
            if (_currentState == UIState.danger)
              Align(
                alignment: Alignment.topCenter,
                child: const Text('🥥', style: TextStyle(fontSize: 50))
                    .animate(onComplete: (controller) => controller.repeat())
                    .slideY(
                        begin: -0.5,
                        end: 10,
                        duration: 2.seconds,
                        curve: Curves.bounceIn)
                    .rotate(duration: 1.seconds),
              ),
            // Main content area
            Center(
              child: _buildContentByState(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black.withOpacity(0.8),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetState,
            ),
            const SizedBox(width: 40), // Spacer for the FAB
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () { /* Could show an info dialog */ },
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        onPressed: _showImageSourceDialog,
        child: const Icon(Icons.camera_alt, size: 32.0, color: Colors.white)
            .animate(
              onComplete: (controller) => controller.repeat(reverse: true),
            )
            .shake(hz: 2, duration: 2.seconds, curve: Curves.easeInOut),
      ),
    );
  }

  // Builds the main content based on the current UI state
  Widget _buildContentByState() {
    switch (_currentState) {
      case UIState.loading:
        return const Text('🥥', style: TextStyle(fontSize: 80))
            .animate(onComplete: (controller) => controller.repeat())
            .rotate(duration: 1.seconds);
      case UIState.danger:
        return _buildAnimatedText("WATCH OUT!", "A coconut might fall on you!");
      case UIState.safe:
        return _buildAnimatedText("You're Safe!", "No coconuts today... 😉");
      case UIState.whatTheThenga:
        return _buildAnimatedText("🤔", "What the Thenga is this?!");
      case UIState.error:
        return _buildAnimatedText("Oops!", _errorMessage, isError: true);
      case UIState.initial:
      default:
        return _buildAnimatedText("Feeling Lucky?", "Let's check for coconuts!");
    }
  }

  // Helper widget for creating animated text blocks
  Widget _buildAnimatedText(String title, String subtitle, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedTextKit(
            animatedTexts: [
              WavyAnimatedText(
                title,
                textAlign: TextAlign.center,
                textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 48,
                  color: isError ? Colors.redAccent : Colors.black87,
                ),
              ),
            ],
            isRepeatingAnimation: false,
          ),
          const SizedBox(height: 16),
          AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                subtitle,
                textAlign: TextAlign.center,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 20),
                speed: const Duration(milliseconds: 50),
              ),
            ],
            isRepeatingAnimation: false,
          ),
        ],
      ),
    );
  }
}
