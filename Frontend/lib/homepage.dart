import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather/weather.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:developer' as developer;
// 1. Import the audioplayers package
import 'package:audioplayers/audioplayers.dart';

// Enum to manage different UI states cleanly
enum UIState { initial, loading, danger, safe, whatTheThenga, error }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// 2. Implement WidgetsBindingObserver to handle app lifecycle (pause/resume)
class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  UIState _currentState = UIState.initial;
  String _errorMessage = '';

  // 3. Create an instance of the AudioPlayer
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    developer.log('initState called.');

    // --- Audio Player Setup ---
    // 4. Configure and start the background music
    _setupAudioPlayer();

    // --- App Lifecycle Observer ---
    // 5. Add the observer to listen for when the app is paused or resumed
    WidgetsBinding.instance.addObserver(this);
  }

  void _setupAudioPlayer() async {
    // Set the release mode to loop for continuous playback
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Start playing the audio from the assets folder.
    // The low-latency mode is better for short sound effects, not long music tracks.
    await _audioPlayer.play(AssetSource('audio/CocoSong.mp3'),
        mode: PlayerMode.mediaPlayer);
    developer.log('Audio player started in loop mode.');
  }

  // 6. Add the App Lifecycle handler
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause the music when the app is in the background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      developer.log('App paused, pausing audio.');
      _audioPlayer.pause();
    }
    // Resume the music when the app is brought back to the foreground
    else if (state == AppLifecycleState.resumed) {
      developer.log('App resumed, resuming audio.');
      _audioPlayer.resume();
    }
  }


  @override
  void dispose() {
    developer.log('dispose called.');
    // 7. Stop and release all resources
    WidgetsBinding.instance.removeObserver(this); // Remove the lifecycle observer
    _audioPlayer.dispose(); // Dispose of the audio player
    super.dispose();
  }


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

    // Increased the timeout to 30 seconds to give the ML model more time
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
      if (e.type == DioExceptionType.badResponse) {
        _handleError("Server error (${e.response?.statusCode}). Check the server logs!", e);
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _handleError("Server is taking too long to respond.", e);
      } else if (e.type == DioExceptionType.connectionError) {
         _handleError("Connection error. Is the server running?", e);
      }
      else {
        _handleError("A network error occurred: ${e.message}", e);
      }
    }
    catch (e, stackTrace) {
      _handleError("An unexpected error occurred during upload.", e, stackTrace);
    }
  }

  Future<void> _getWeather() async {
    developer.log('Fetching weather data...');
    const String weatherApiKey = "a47bba80b386d8e342e66deb236e6d85";

    if (weatherApiKey == "YOUR_WEATHER_API_KEY") {
      _handleError("Please add your Weather API key!");
      return;
    }

    try {
      // 1. Check if location services are enabled.
      developer.log('Checking if location services are enabled...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleError('Location services are disabled.');
        return;
      }
      developer.log('Location services are enabled.');

      // 2. Check and request permissions.
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

      // 3. Get the current position with robust settings.
      developer.log('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: true, // Use this to improve reliability on some emulators
      );
      developer.log('Position received: $position');

      // 4. Fetch weather data.
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
    } catch (e, stackTrace) {
      _handleError("Could not get location or weather data.", e, stackTrace);
    }
  }

  void _handleError(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      'Handling error: $message',
      error: error,
      stackTrace: stackTrace,
      name: 'CoconutAppError'
    );
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