import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B8DEF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FF),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF17324D),
          displayColor: const Color(0xFF17324D),
        ),
      ),
      home: const WeatherPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Модель погоды
// ---------------------------------------------------------------------------

class WeatherData {
  final String cityName;
  final double temperature;
  final double windSpeed;
  final int humidity;
  final int weatherCode;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.windSpeed,
    required this.humidity,
    required this.weatherCode,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, String city) {
    final current = json['current'] as Map<String, dynamic>;
    return WeatherData(
      cityName: city,
      temperature: (current['temperature_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      weatherCode: (current['weather_code'] as num).toInt(),
    );
  }

  String get condition {
    switch (weatherCode) {
      case 0:
        return 'Ясно';
      case 1:
      case 2:
      case 3:
        return 'Облачно';
      case 45:
      case 48:
        return 'Туман';
      case 51:
      case 53:
      case 55:
        return 'Морось';
      case 61:
      case 63:
      case 65:
        return 'Дождь';
      case 71:
      case 73:
      case 75:
        return 'Снег';
      case 80:
      case 81:
      case 82:
        return 'Ливень';
      case 95:
        return 'Гроза';
      default:
        return 'Неизвестно';
    }
  }

  IconData get icon {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.cloud;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit;
      case 95:
        return Icons.thunderstorm;
      default:
        return Icons.help_outline;
    }
  }

  List<Color> get gradientColors {
    switch (weatherCode) {
      case 0:
        return const [Color(0xFF67C8FF), Color(0xFF3B82F6)];
      case 1:
      case 2:
      case 3:
        return const [Color(0xFF9CC3FF), Color(0xFF6A8DFF)];
      case 45:
      case 48:
        return const [Color(0xFFB0BEC5), Color(0xFF90A4AE)];
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return const [Color(0xFF5CC7FF), Color(0xFF2C7BEA)];
      case 71:
      case 73:
      case 75:
        return const [Color(0xFFB8E1FF), Color(0xFF78A7FF)];
      case 95:
        return const [Color(0xFF5C6BFF), Color(0xFF2F3B9A)];
      default:
        return const [Color(0xFF9AA8B8), Color(0xFF7187A6)];
    }
  }
}

// ---------------------------------------------------------------------------
// Сервис погоды
// ---------------------------------------------------------------------------

class WeatherService {
  /// Ищет координаты города по имени через Geocoding API.
  static Future<Map<String, dynamic>?> searchCity(String cityName) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(cityName)}&count=1&language=ru',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) return null;

    return results.first as Map<String, dynamic>;
  }

  /// Получает текущую погоду по координатам.
  static Future<WeatherData> getWeather({
    required double latitude,
    required double longitude,
    required String cityName,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
      '&timezone=auto',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки погоды');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherData.fromJson(data, cityName);
  }
}

// ---------------------------------------------------------------------------
// Экран погоды
// ---------------------------------------------------------------------------

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  WeatherData? _weather;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _searchByCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Введите название города');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final location = await WeatherService.searchCity(city);
      if (location == null) {
        setState(() {
          _error = 'Город не найден';
          _loading = false;
        });
        return;
      }

      final lat = (location['latitude'] as num).toDouble();
      final lon = (location['longitude'] as num).toDouble();
      final name = location['name'] as String? ?? city;

      final weather = await WeatherService.getWeather(
        latitude: lat,
        longitude: lon,
        cityName: name,
      );

      setState(() {
        _weather = weather;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _searchByCoordinates() async {
    final latText = _latController.text.trim();
    final lonText = _lonController.text.trim();

    final lat = double.tryParse(latText);
    final lon = double.tryParse(lonText);

    if (lat == null || lon == null) {
      setState(() => _error = 'Введите корректные координаты');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final weather = await WeatherService.getWeather(
        latitude: lat,
        longitude: lon,
        cityName: '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
      );

      setState(() {
        _weather = weather;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF3FF), Color(0xFFF8FBFF)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Погода',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17324D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Проверьте текущую погоду в вашем городе',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5B6F86),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  hintText: 'Введите город',
                                  labelText: 'Город',
                                  filled: true,
                                  fillColor: Color(0xFFF3F7FF),
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onSubmitted: (_) => _searchByCity(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: const Color(0xFF5B8DEF),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _searchByCity,
                                child: const SizedBox(
                                  width: 50,
                                  height: 56,
                                  child: Icon(Icons.search, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latController,
                                decoration: const InputDecoration(
                                  hintText: 'Широта',
                                  labelText: 'Широта',
                                  filled: true,
                                  fillColor: Color(0xFFF3F7FF),
                                  prefixIcon: Icon(Icons.my_location_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _lonController,
                                decoration: const InputDecoration(
                                  hintText: 'Долгота',
                                  labelText: 'Долгота',
                                  filled: true,
                                  fillColor: Color(0xFFF3F7FF),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _searchByCoordinates,
                                child: const SizedBox(
                                  width: 50,
                                  height: 56,
                                  child: Icon(Icons.gps_fixed_rounded, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (_weather != null)
                  _WeatherCard(weather: _weather!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка погоды
// ---------------------------------------------------------------------------

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final WeatherData weather;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: weather.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: weather.gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  weather.cityName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  weather.condition,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(weather.icon, size: 78, color: Colors.white),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temperature.toStringAsFixed(1)}°',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Celsius',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.air,
                  label: 'Ветер',
                  value: '${weather.windSpeed.toStringAsFixed(1)} км/ч',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoItem(
                  icon: Icons.water_drop,
                  label: 'Влажность',
                  value: '${weather.humidity}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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