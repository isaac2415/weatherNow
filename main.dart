import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          primary: Color(0xFF6B73FF),
          secondary: Color(0xFFFF6B9D),
          background: Color(0xFFF8FAFF),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF6B73FF),
          secondary: Color(0xFFFF6B9D),
          background: Color(0xFF0A0E21),
        ),
      ),
      home: MyHome(),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  final String apiKey = 'fd831789ad0b9faf29fa71352617331b';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? forecastData;
  bool isLoading = false;
  bool isLoadingLocation = false;
  String errorMessage = '';
  String cityName = 'Getting location...';
  bool isDarkMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _refreshData() async {
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      errorMessage = '';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'Location permissions denied';
            isLoadingLocation = false;
            cityName = 'Lilongwe';
          });
          await _fetchWeatherData(cityName);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage = 'Location permissions permanently denied';
          isLoadingLocation = false;
          cityName = 'Lilongwe';
        });
        await _fetchWeatherData(cityName);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      await _fetchWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to get location. Using default city.';
        isLoadingLocation = false;
        cityName = 'Lilongwe';
      });
      await _fetchWeatherData(cityName);
    }
  }

  Future<void> _fetchWeatherByCoordinates(double lat, double lon) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
        ),
      );

      final forecastResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
        ),
      );

      if (weatherResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        setState(() {
          weatherData = json.decode(weatherResponse.body);
          forecastData = json.decode(forecastResponse.body);
          cityName = weatherData!['name'];
          isLoading = false;
          isLoadingLocation = false;
        });
        _startAnimation();
      } else {
        setState(() {
          errorMessage = 'Failed to fetch weather data';
          isLoading = false;
          isLoadingLocation = false;
          cityName = 'Lilongwe';
        });
        await _fetchWeatherData(cityName);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch weather data. Check your connection.';
        isLoading = false;
        isLoadingLocation = false;
        cityName = 'Lilongwe';
      });
      await _fetchWeatherData(cityName);
    }
  }

  Future<void> _fetchWeatherData(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric',
        ),
      );

      final forecastResponse = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric',
        ),
      );

      if (weatherResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        setState(() {
          weatherData = json.decode(weatherResponse.body);
          forecastData = json.decode(forecastResponse.body);
          isLoading = false;
          cityName = city;
        });
        _startAnimation();
      } else {
        setState(() {
          errorMessage = 'City not found. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch weather data. Check your connection.';
        isLoading = false;
      });
    }
  }

  void _searchCity() {
    if (_searchController.text.trim().isNotEmpty) {
      String city = _searchController.text.trim();
      String formattedCity =
          city[0].toUpperCase() + city.substring(1).toLowerCase();
      _fetchWeatherData(formattedCity);
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _toggleDarkMode() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  String _getWeatherIcon(String mainCondition) {
    switch (mainCondition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  String _getDayOfWeek(int index) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final now = DateTime.now();
    final targetDay = now.add(Duration(days: index));
    return days[targetDay.weekday % 7];
  }

  List<Map<String, dynamic>> _getWeeklyForecast() {
    if (forecastData == null) return [];

    final List<Map<String, dynamic>> weeklyData = [];
    final dailyTemps = <String, List<double>>{};

    for (var item in forecastData!['list']) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dateKey = '${date.year}-${date.month}-${date.day}';

      if (!dailyTemps.containsKey(dateKey)) {
        dailyTemps[dateKey] = [];
      }
      dailyTemps[dateKey]!.add(item['main']['temp']);
    }

    int dayIndex = 0;
    dailyTemps.forEach((dateKey, temps) {
      if (dayIndex < 7) {
        final date = DateTime.parse(dateKey);
        final dailyForecast = forecastData!['list'].firstWhere(
          (item) =>
              DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000).day ==
              date.day,
          orElse: () => forecastData!['list'][0],
        );

        weeklyData.add({
          'day': _getDayOfWeek(dayIndex),
          'condition': dailyForecast['weather'][0]['main'],
          'minTemp': temps.reduce((a, b) => a < b ? a : b),
          'maxTemp': temps.reduce((a, b) => a > b ? a : b),
          'icon': dailyForecast['weather'][0]['main'],
        });
        dayIndex++;
      }
    });

    return weeklyData;
  }

  Color _getBackgroundColor() {
    return isDarkMode ? Color(0xFF0A0E21) : Color(0xFFF8FAFF);
  }

  Color _getCardColor() {
    return isDarkMode ? Color(0xFF1D1F33) : Colors.white;
  }

  Color _getTextColor() {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color _getSecondaryTextColor() {
    return isDarkMode ? Colors.white70 : Colors.grey[700]!;
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: _getCardColor(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Weather App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.info, color: _getTextColor()),
              title: Text(
                'Developer Info',
                style: TextStyle(
                  color: _getTextColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: _getSecondaryTextColor()),
            ),
            _buildDrawerItem('Name', 'Ibrahi Isaac', Icons.person),
            _buildDrawerItem('Location', 'Lilongwe Area 21', Icons.location_on),
            _buildDrawerItem('Email', 'isaacibrah4@gmail.com', Icons.email),
            _buildDrawerItem('App Version', '1.0.0', Icons.apps),
            SizedBox(height: 30),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Weather data provided by OpenWeatherMap',
                style: TextStyle(
                  color: _getSecondaryTextColor(),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, color: _getSecondaryTextColor()),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: _getTextColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        key: _scaffoldKey, // Added scaffold key
        backgroundColor: _getBackgroundColor(),
        drawer: _buildDrawer(),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Menu and Dark Mode Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            _scaffoldKey.currentState
                                ?.openDrawer(); // Fixed drawer opening
                          },
                          icon: Icon(
                            Icons.menu,
                            color: _getTextColor(),
                            size: screenWidth * 0.07,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Weather',
                              style: TextStyle(
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.w300,
                                color: _getTextColor(),
                              ),
                            ),
                            Text(
                              cityName,
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.w500,
                                color: _getSecondaryTextColor(),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _toggleDarkMode,
                          icon: Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: _getTextColor(),
                            size: screenWidth * 0.07,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Search Field
                    _buildSearchField(screenWidth),
                    SizedBox(height: screenHeight * 0.02),

                    // Error Message
                    if (errorMessage.isNotEmpty) _buildErrorMessage(),

                    if (isLoadingLocation)
                      _buildLoadingIndicator('Getting your location...')
                    else if (isLoading)
                      _buildLoadingIndicator('Loading weather data...')
                    else if (weatherData != null && forecastData != null)
                      _buildWeatherContent(screenHeight, screenWidth),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _getCurrentLocation,
          child: Icon(Icons.my_location, color: Colors.white),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildSearchField(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search city...',
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.send,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _searchCity,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onSubmitted: (_) => _searchCity(),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 10),
          Expanded(
            child: Text(errorMessage, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(color: _getSecondaryTextColor(), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent(double screenHeight, double screenWidth) {
    return Column(
      children: [
        // Current Temperature Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                Theme.of(context).colorScheme.secondary.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeatherIcon(weatherData!['weather'][0]['main']),
                    style: TextStyle(fontSize: screenWidth * 0.15),
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weatherData!['main']['temp']?.toStringAsFixed(1) ?? 'N/A'}°',
                        style: TextStyle(
                          fontSize: screenWidth * 0.12,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        weatherData!['weather'][0]['description'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Feels like ${weatherData!['main']['feels_like']?.toStringAsFixed(1) ?? 'N/A'}°',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: screenHeight * 0.03),

        // Today's Details Section
        Text(
          'Today\'s Details',
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.w600,
            color: _getTextColor(),
          ),
        ),

        SizedBox(height: screenHeight * 0.02),

        // Weather Details Grid
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildDetailCard(
              'Wind',
              '${weatherData!['wind']['speed']?.toStringAsFixed(1) ?? 'N/A'} m/s',
              Icons.air,
              screenWidth,
            ),
            _buildDetailCard(
              'Humidity',
              '${weatherData!['main']['humidity']?.toString() ?? 'N/A'}%',
              Icons.water_drop,
              screenWidth,
            ),
            _buildDetailCard(
              'Pressure',
              '${weatherData!['main']['pressure']?.toString() ?? 'N/A'} hPa',
              Icons.compress,
              screenWidth,
            ),
            _buildDetailCard(
              'Visibility',
              '${(weatherData!['visibility'] ?? 0) / 1000} km',
              Icons.visibility,
              screenWidth,
            ),
          ],
        ),

        SizedBox(height: screenHeight * 0.03),

        // Weekly Forecast Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '7-Day Forecast',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.w600,
                color: _getTextColor(),
              ),
            ),
            Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary,
              size: screenWidth * 0.06,
            ),
          ],
        ),

        SizedBox(height: screenHeight * 0.02),

        // Weekly Forecast List
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _getCardColor(),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _getWeeklyForecast()
                .map(
                  (dayForecast) => _buildWeeklyForecastItem(
                    dayForecast['day'],
                    dayForecast['icon'],
                    dayForecast['minTemp'],
                    dayForecast['maxTemp'],
                    screenWidth,
                  ),
                )
                .toList(),
          ),
        ),

        SizedBox(height: screenHeight * 0.02),
      ],
    );
  }

  Widget _buildDetailCard(
    String title,
    String value,
    IconData icon,
    double width,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: width * 0.08,
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.04,
              color: _getSecondaryTextColor(),
            ),
          ),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: width * 0.045,
              fontWeight: FontWeight.w600,
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecastItem(
    String day,
    String condition,
    double minTemp,
    double maxTemp,
    double width,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: TextStyle(
                fontSize: width * 0.045,
                fontWeight: FontWeight.w500,
                color: _getTextColor(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getWeatherIcon(condition),
              style: TextStyle(fontSize: width * 0.06),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${maxTemp.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: width * 0.045,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(),
                  ),
                ),
                SizedBox(width: width * 0.03),
                Text(
                  '${minTemp.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: width * 0.045,
                    color: _getSecondaryTextColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
