import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather/weather.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:developer' as developer;

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
    developer.log('Attempting to pick image from $source...');
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);

    if (image != null) {
      developer.log('Image picked successfully: ${image.path}');
      _uploadImage(File(image.path));
    } else {
      developer.log('Image picking cancelled.');
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
    developer.log('Starting image upload...');

    String fileName = image.path.split('/').last;
    FormData formData = FormData.fromMap({
      "picture": await MultipartFile.fromFile(image.path, filename: fileName),
    });

    const String apiUrl = 'http://10.0.2.2:3000/predict';
    developer.log('Uploading to API: $apiUrl');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    try {
      final response = await dio.post(apiUrl, data: formData);
      developer.log('API Response Status: ${response.statusCode}');
      developer.log('API Response Data: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        bool isCoconutTree = response.data['prediction']['isCoconutTree'];
        developer.log('Prediction - isCoconutTree: $isCoconutTree');
        if (isCoconutTree) {
          await _getWeather();
        } else {
          setState(() => _currentState = UIState.whatTheThenga);
        }
      } else {
        _handleError("Prediction failed. Status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      developer.log('DioException: ${e.toString()}', error: e);
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _handleError("Server is taking too long to respond.");
      } else if (e.type == DioExceptionType.connectionError) {
         _handleError("Connection error. Is the server running?");
      }
      else {
        _handleError("A network error occurred.");
      }
    }
    catch (e) {
      developer.log('Unexpected Error in _uploadImage: ${e.toString()}', error: e);
      _handleError("An unexpected error occurred during upload.");
    }
  }

  Future<void> _getWeather() async {
    developer.log('Fetching weather data...');
    const String weatherApiKey = "a47bba80b386d8e342e66deb236e6d85";

    if (weatherApiKey == "YOUR_WEATHER_API_KEY") {
      developer.log('Weather API key is missing!', error: true);
      _handleError("Please add your Weather API key!");
      return;
    }

    try {
      developer.log('Checking location permissions...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      developer.log('Location permission status: $permission');

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _handleError("Location permissions are denied.");
        return;
      }

      developer.log('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      developer.log('Position received: $position');

      WeatherFactory wf = WeatherFactory(weatherApiKey);
      Weather w = await wf.currentWeatherByLocation(position.latitude, position.longitude);
      developer.log('Weather data received: ${w.toString()}');

      if (w.windSpeed != null && w.windSpeed! > 2) {
        developer.log('Wind speed is high (${w.windSpeed}), setting state to DANGER');
        setState(() => _currentState = UIState.danger);
      } else {
        developer.log('Wind speed is low (${w.windSpeed}), setting state to SAFE');
        setState(() => _currentState = UIState.safe);
      }
    } catch (e) {
      developer.log('Error in _getWeather: ${e.toString()}', error: e);
      _handleError("Could not get location or weather data.");
    }
  }

  void _handleError(String message) {
    developer.log('Handling error: $message', error: true);
    setState(() {
      _currentState = UIState.error;
      _errorMessage = message;
    });
  }

  void _resetState() {
    developer.log('Resetting state to initial.');
    setState(() => _currentState = UIState.initial);
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building UI for state: $_currentState');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
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
