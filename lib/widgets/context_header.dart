import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_manager.dart';
import '../services/launcher_service.dart';
import 'virtual_topography.dart';

enum HeaderMode {
  filter,
  timeSpace,
  none,
}

class MultiCalendarHelper {
  static String getMayanKinDate(DateTime date) {
    final anchor = DateTime.utc(2020, 1, 1);
    final target = DateTime.utc(date.year, date.month, date.day);
    
    int days = 0;
    if (target.isAfter(anchor)) {
      DateTime current = anchor;
      while (current.isBefore(target)) {
        if (!(current.month == 2 && current.day == 29)) {
          days++;
        }
        current = current.add(const Duration(days: 1));
      }
    } else {
      DateTime current = anchor;
      while (current.isAfter(target)) {
        current = current.subtract(const Duration(days: 1));
        if (!(current.month == 2 && current.day == 29)) {
          days--;
        }
      }
    }
    
    int kin = (178 + days) % 260;
    if (kin <= 0) kin += 260;
    
    final tones = [
      "Magnético (1)", "Lunar (2)", "Elétrico (3)", "Autoexistente (4)",
      "Harmônico (5)", "Rítmico (6)", "Ressonante (7)", "Galáctico (8)",
      "Solar (9)", "Planetário (10)", "Espectral (11)", "Cristal (12)", "Cósmico (13)"
    ];
    
    final seals = [
      "Dragão Vermelho (Imix)", "Vento Branco (Ik)", "Noite Azul (Akbal)", "Semente Amarela (Kan)",
      "Serpente Vermelha (Chicchan)", "Enlaçador de Mundos Branco (Cimi)", "Mão Azul (Manik)", "Estrela Amarela (Lamat)",
      "Lua Vermelha (Muluc)", "Cachorro Branco (Oc)", "Macaco Azul (Chuen)", "Humano Amarelo (Eb)",
      "Caminhante do Céu Vermelho (Ben)", "Mago Branco (Ix)", "Águia Azul (Men)", "Guerreiro Amarelo (Cib)",
      "Terra Vermelha (Caban)", "Espelho Branco (Etznab)", "Tormenta Azul (Cauac)", "Sol Amarelo (Ahau)"
    ];
    
    int toneIndex = (kin - 1) % 13;
    int sealIndex = (kin - 1) % 20;
    
    final toneName = tones[toneIndex];
    final sealName = seals[sealIndex];
    
    return "Kin $kin: $sealName $toneName";
  }

  static int getJulianDay(DateTime date) {
    int y = date.year;
    int m = date.month;
    int d = date.day;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = (a / 4).floor();
    final c = 2 - a + b;
    final e = (365.25 * (y + 4716)).floor();
    final f = (30.6001 * (m + 1)).floor();
    return c + d + e + f - 1524;
  }

  static String getHebrewDate(DateTime date) {
    final jd = getJulianDay(date);
    final rhJds = {
      5785: 2460585,
      5786: 2460941,
      5787: 2461295,
      5788: 2461680,
      5789: 2462035,
      5790: 2462389,
      5791: 2462772,
      5792: 2463126,
    };

    int year = 5786;
    int startJd = rhJds[5786]!;
    for (var entry in rhJds.entries) {
      if (jd >= entry.value) {
        year = entry.key;
        startJd = entry.value;
      }
    }

    final dayOfYear = jd - startJd + 1;
    final yearInCycle = year % 19;
    final isLeap = [3, 6, 8, 11, 14, 17, 0].contains(yearInCycle);

    final nextRh = rhJds[year + 1] ?? (startJd + 354);
    final yearLength = nextRh - startJd;

    int cheshvanLen = 29;
    int kislevLen = 30;
    if (yearLength == 355 || yearLength == 385) {
      cheshvanLen = 30;
    } else if (yearLength == 353 || yearLength == 383) {
      kislevLen = 29;
    }

    final List<int> monthLengths;
    final List<String> monthNames;

    if (isLeap) {
      monthLengths = [30, cheshvanLen, kislevLen, 29, 30, 30, 29, 30, 29, 30, 29, 30, 29];
      monthNames = [
        "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar II",
        "Nisan", "Iyar", "Sivan", "Tamuz", "Av", "Elul"
      ];
    } else {
      monthLengths = [30, cheshvanLen, kislevLen, 29, 30, 29, 30, 29, 30, 29, 30, 29];
      monthNames = [
        "Tishrei", "Cheshvan", "Kislev", "Tevet", "Shevat", "Adar", "Nisan",
        "Iyar", "Sivan", "Tamuz", "Av", "Elul"
      ];
    }

    int remainingDays = dayOfYear;
    int monthIdx = 0;
    while (remainingDays > monthLengths[monthIdx]) {
      remainingDays -= monthLengths[monthIdx];
      monthIdx++;
      if (monthIdx >= monthLengths.length) break;
    }

    return "$remainingDays de ${monthNames[monthIdx.clamp(0, monthNames.length - 1)]}, $year";
  }

  static String getHijriDate(DateTime date) {
    final jd = getJulianDay(date);
    final hijriJds = {
      1446: 2460499,
      1447: 2460853,
      1448: 2461208,
      1449: 2461562,
      1450: 2461917,
      1451: 2462271,
      1452: 2462625,
    };

    int year = 1448;
    int startJd = hijriJds[1448]!;
    for (var entry in hijriJds.entries) {
      if (jd >= entry.value) {
        year = entry.key;
        startJd = entry.value;
      }
    }

    final dayOfYear = jd - startJd + 1;
    final isLeap = ((11 * year + 14) % 30) < 11;

    final monthLengths = [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, isLeap ? 30 : 29];
    final monthNames = [
      "Muharram", "Safar", "Rabi' I", "Rabi' II", "Jumada I", "Jumada II",
      "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah"
    ];

    int remainingDays = dayOfYear;
    int monthIdx = 0;
    while (remainingDays > monthLengths[monthIdx]) {
      remainingDays -= monthLengths[monthIdx];
      monthIdx++;
      if (monthIdx >= monthLengths.length) break;
    }

    return "$remainingDays de ${monthNames[monthIdx.clamp(0, monthNames.length - 1)]}, $year AH";
  }

  static String getChineseDate(DateTime date) {
    final jd = getJulianDay(date);
    final chineseNewYears = {
      2025: 2460705,
      2026: 2461089,
      2027: 2461443,
      2028: 2461797,
      2029: 2462181,
      2030: 2462536,
    };

    final zodiacs = {
      2025: "Cobra (乙巳)",
      2026: "Cavalo (丙午)",
      2027: "Cabra (丁未)",
      2028: "Macaco (戊申)",
      2029: "Galo (己酉)",
      2030: "Cão (庚戌)",
    };

    int year = 2026;
    int startJd = chineseNewYears[2026]!;
    for (var entry in chineseNewYears.entries) {
      if (jd >= entry.value) {
        year = entry.key;
        startJd = entry.value;
      }
    }

    final dayOfYear = jd - startJd + 1;
    final double monthVal = dayOfYear / 29.53059;
    final int month = monthVal.floor() + 1;
    final int day = (dayOfYear - ((month - 1) * 29.53059).round()).clamp(1, 30);

    return "Dia $day do Mês $month, Ano do ${zodiacs[year] ?? "Cavalo"}";
  }

  static String getGregorianDate(DateTime date) {
    const weekdays = [
      'Segunda-feira', 'Terça-feira', 'Quarta-feira',
      'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'
    ];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return "${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]} de ${date.year}";
  }
}

class ContextHeader extends StatefulWidget {
  const ContextHeader({super.key});

  static final ValueNotifier<HeaderMode> isPanelOpenNotifier = ValueNotifier(HeaderMode.filter);
  static final ValueNotifier<bool> isExtendedNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> locationUpdateNotifier = ValueNotifier(false);

  static Future<void> saveHeaderMode(HeaderMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('portal_header_mode', mode.name);
    } catch (_) {}
  }

  static Future<void> loadHeaderMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('portal_header_mode');
      if (modeStr != null) {
        final mode = HeaderMode.values.firstWhere((e) => e.name == modeStr, orElse: () => HeaderMode.filter);
        isPanelOpenNotifier.value = mode;
      }
    } catch (_) {}
  }

  @override
  State<ContextHeader> createState() => _ContextHeaderState();
}

class _ContextHeaderState extends State<ContextHeader> with SingleTickerProviderStateMixin {
  late DateTime _currentTime;
  late Timer _timer;
  String _weatherTemp = '--';
  String _weatherDesc = '--';
  String _cityName = 'Curitiba, Paraná, Brasil'; // Shown while GPS loads; replaced by cache or real location
  String _onlyCityName = 'Curitiba';
  double _userLat = -25.4284;
  double _userLon = -49.2733;
  double _apparentTemp = 21.0;
  int _relativeHumidity = 65;
  double _windSpeed = 12.0;
  double _windDirection = 180.0;
  double _surfacePressure = 1012.0;
  double _uvIndex = 3.0;
  String _sunriseTime = '06:45';
  String _sunsetTime = '18:03';
  double _userAltitude = 934.0;
  double _gpsAccuracy = 15.0;
  bool _isFahrenheit = false;
  double _weatherTempCelsius = 15.0;
  bool _showPanel = false;
  bool _isExtended = false;
  int _calendarSystemIndex = 0; // 0: Gregorian, 1: Chinese, 2: Hebrew, 3: Hijri
  int _tapCount = 0;
  Timer? _tapTimer;
  final List<int> _tapTimestamps = [];
  late AnimationController _animationController;
  late Animation<double> _animation;

  String _getTimezoneLabel() {
    final offset = _currentTime.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.abs() % 60;
    final sign = hours >= 0 ? '+' : '-';
    if (minutes == 0) {
      return 'UTC$sign${hours.abs()}';
    }
    return 'UTC$sign${hours.abs()}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    ContextHeader.isExtendedNotifier.addListener(_onExtendedChanged);
    ContextHeader.locationUpdateNotifier.addListener(_onLocationUpdatedNotification);
    ContextHeader.isPanelOpenNotifier.addListener(_onPanelOpenNotifierChanged);
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 1. Load cached city name instantly (no delay)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('portal_city_name');
    final cachedLat = prefs.getDouble('portal_last_lat');
    final cachedLon = prefs.getDouble('portal_last_lon');
    final cachedOnlyCity = prefs.getString('portal_only_city_name');
    if (cached != null && mounted) {
      setState(() {
        _cityName = cached;
        if (cachedOnlyCity != null) {
          _onlyCityName = cachedOnlyCity;
        }
      });
    }
    if (cachedLat != null && cachedLon != null) {
      _userLat = cachedLat;
      _userLon = cachedLon;
      // Fire weather immediately with cached coords while we fetch real GPS
      _fetchWeather(cachedLat, cachedLon);
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (cached == null) await _fetchCityName(_userLat, _userLon);
        if (cachedLat == null) await _fetchWeather(_userLat, _userLon);
        return;
      }

      // Try last known position first (instant, no GPS wait)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        if (mounted) setState(() { _userLat = last.latitude; _userLon = last.longitude; });
        if (cached == null) await _fetchCityName(last.latitude, last.longitude);
        _fetchWeather(last.latitude, last.longitude);
      }

      // Then get accurate position in background
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) setState(() { _userLat = pos.latitude; _userLon = pos.longitude; });
      await _fetchCityName(pos.latitude, pos.longitude);
      await _fetchWeather(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted && _cityName == 'Curitiba, BR' && cached == null) {
        await _fetchCityName(_userLat, _userLon);
      }
      await _fetchWeather(_userLat, _userLon);
    }
  }

  Future<void> _fetchCityName(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=10');
      final response = await http.get(uri, headers: {
        'Accept-Language': 'pt-BR',
        'User-Agent': 'PortalLauncher/1.0 (android; contact@portallauncher.app)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        final neighborhood = address?['suburb'] ?? address?['neighbourhood'] ?? address?['city_district'] ?? '';
        final city = address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['municipality'] ?? address?['county'] ?? '';
        final state = address?['state'] ?? '';
        final country = address?['country'] ?? '';

        final parts = <String>[];
        if (neighborhood.toString().isNotEmpty) parts.add(neighborhood.toString());
        if (city.toString().isNotEmpty) parts.add(city.toString());
        if (state.toString().isNotEmpty) parts.add(state.toString());
        if (country.toString().isNotEmpty) parts.add(country.toString());
        
        final name = parts.isNotEmpty ? parts.join(', ') : 'Curitiba, Paraná, Brasil';
        final cityStr = city.toString().isNotEmpty ? city.toString() : 'Curitiba';
        
        if (mounted) {
          setState(() {
            _cityName = name;
            _onlyCityName = cityStr;
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('portal_city_name', name);
        await prefs.setString('portal_only_city_name', cityStr);
        await prefs.setDouble('portal_last_lat', lat);
        await prefs.setDouble('portal_last_lon', lon);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer.cancel();
    ContextHeader.isExtendedNotifier.removeListener(_onExtendedChanged);
    ContextHeader.locationUpdateNotifier.removeListener(_onLocationUpdatedNotification);
    ContextHeader.isPanelOpenNotifier.removeListener(_onPanelOpenNotifierChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onPanelOpenNotifierChanged() {
    if (!mounted) return;
    final mode = ContextHeader.isPanelOpenNotifier.value;
    setState(() {
      _showPanel = (mode == HeaderMode.timeSpace);
      if (_showPanel) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onExtendedChanged() {
    if (mounted) {
      setState(() {
        _isExtended = ContextHeader.isExtendedNotifier.value;
      });
    }
  }

  void _onLocationUpdatedNotification() {
    _initLocation();
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,surface_pressure&daily=sunrise,sunset,uv_index_max&timezone=auto');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        final daily = data['daily'];
        
        final temp = current['temperature_2m'];
        final code = current['weather_code'];
        final appTemp = current['apparent_temperature'] ?? temp;
        final humidity = current['relative_humidity_2m'] ?? 65;
        final windSp = current['wind_speed_10m'] ?? 12.0;
        final windDir = current['wind_direction_10m'] ?? 180.0;
        final press = current['surface_pressure'] ?? 1012.0;
        
        final altitude = data['elevation'] ?? 0.0;
        
        String sunrise = '06:45';
        String sunset = '18:03';
        double uvMax = 3.0;
        
        if (daily != null) {
          if (daily['sunrise'] != null && (daily['sunrise'] as List).isNotEmpty) {
            final String rawSunrise = daily['sunrise'][0];
            if (rawSunrise.contains('T')) {
              sunrise = rawSunrise.split('T')[1];
            }
          }
          if (daily['sunset'] != null && (daily['sunset'] as List).isNotEmpty) {
            final String rawSunset = daily['sunset'][0];
            if (rawSunset.contains('T')) {
              sunset = rawSunset.split('T')[1];
            }
          }
          if (daily['uv_index_max'] != null && (daily['uv_index_max'] as List).isNotEmpty) {
            uvMax = (daily['uv_index_max'][0] as num).toDouble();
          }
        }

        if (mounted) {
          setState(() {
            _weatherTempCelsius = (temp as num).toDouble();
            _weatherTemp = '${_weatherTempCelsius.toStringAsFixed(0)}°C';
            _apparentTemp = (appTemp as num).toDouble();
            _relativeHumidity = (humidity as num).toInt();
            _windSpeed = (windSp as num).toDouble();
            _windDirection = (windDir as num).toDouble();
            _surfacePressure = (press as num).toDouble();
            _uvIndex = uvMax;
            _sunriseTime = sunrise;
            _sunsetTime = sunset;
            if (altitude > 0) {
              _userAltitude = (altitude as num).toDouble();
            }
            _interpretWeatherCode(code as int);
          });
        }
      }
    } catch (_) {}
  }

  void _interpretWeatherCode(int code) {
    if (code == 0) {
      _weatherDesc = 'Céu Limpo';
    } else if (code >= 1 && code <= 3) {
      _weatherDesc = 'Parcialmente Nublado';
    } else if (code >= 45 && code <= 48) {
      _weatherDesc = 'Nevoeiro';
    } else if (code >= 51 && code <= 67) {
      _weatherDesc = 'Chuvisco';
    } else if (code >= 80 && code <= 82) {
      _weatherDesc = 'Pancadas de Chuva';
    } else {
      _weatherDesc = 'Chuva';
    }
  }

  void _togglePanel() {
    setState(() {
      final currentMode = ContextHeader.isPanelOpenNotifier.value;
      if (currentMode == HeaderMode.none) {
        return;
      }
      final nextMode = currentMode == HeaderMode.filter
          ? HeaderMode.timeSpace
          : HeaderMode.filter;

      ContextHeader.isPanelOpenNotifier.value = nextMode;
      _showPanel = (nextMode == HeaderMode.timeSpace);

      if (nextMode == HeaderMode.timeSpace) {
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _showPanel) {
            _animationController.forward();
          }
        });
      } else {
        _animationController.reverse();
      }
    });
  }

  void _cycleCalendar() {
    setState(() {
      _calendarSystemIndex = (_calendarSystemIndex + 1) % 5;
    });
  }

  String _getCalendarDateString() {
    switch (_calendarSystemIndex) {
      case 1:
        return MultiCalendarHelper.getChineseDate(_currentTime);
      case 2:
        return MultiCalendarHelper.getHebrewDate(_currentTime);
      case 3:
        return MultiCalendarHelper.getHijriDate(_currentTime);
      case 4:
        return MultiCalendarHelper.getMayanKinDate(_currentTime);
      case 0:
      default:
        return MultiCalendarHelper.getGregorianDate(_currentTime);
    }
  }

  Widget _getCalendarSymbolWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black.withOpacity(0.8);
    
    return CustomPaint(
      size: const Size(14, 14),
      painter: _CalendarSymbolPainter(_calendarSystemIndex, color),
    );
  }

  Map<String, dynamic> _getMoonPhaseInfo() {
    // Known New Moon: Jan 6, 2000, 18:14 UTC
    final refDate = DateTime.utc(2000, 1, 6, 18, 14);
    final nowUtc = DateTime.now().toUtc();
    final diffDays = nowUtc.difference(refDate).inMilliseconds / (1000 * 60 * 60 * 24);
    final age = diffDays % 29.530588853;

    if (age >= 13.0 && age <= 16.5) {
      return {
        'icon': Icons.brightness_1_rounded,
        'symbol': '🌕',
        'name': 'Lua Cheia',
      };
    } else if (age > 16.5 && age < 27.5) {
      return {
        'icon': Icons.brightness_3_rounded,
        'symbol': '🌘',
        'name': 'Lua Minguante',
      };
    } else if (age > 2.0 && age < 13.0) {
      return {
        'icon': Icons.brightness_3_rounded,
        'symbol': '🌒',
        'name': 'Lua Crescente',
      };
    } else {
      return {
        'icon': Icons.brightness_2_rounded,
        'symbol': '🌑',
        'name': 'Lua Nova',
      };
    }
  }

  IconData? _getWeatherIconData() {
    final desc = _weatherDesc.toLowerCase();
    if (desc.contains('limpo') || desc.contains('clear')) {
      return Icons.wb_sunny_rounded;
    } else if (desc.contains('sol') || desc.contains('sunny')) {
      return Icons.wb_sunny_rounded;
    } else if (desc.contains('nublado') || desc.contains('cloud')) {
      return Icons.cloud_rounded;
    } else if (desc.contains('chuva') || desc.contains('rain') || desc.contains('chuvisco')) {
      return Icons.umbrella_rounded;
    } else if (desc.contains('neve') || desc.contains('snow')) {
      return Icons.ac_unit_rounded;
    } else if (desc.contains('nevoeiro') || desc.contains('fog') || desc.contains('névoa')) {
      return Icons.foggy;
    }
    return Icons.wb_cloudy_rounded;
  }

  String _getMoonZodiacSign(DateTime date) {
    final jd = MultiCalendarHelper.getJulianDay(date);
    final double daysSinceEpoch = jd - 2451545.0;
    final double moonLong = (13.17639 * daysSinceEpoch + 218.316) % 360.0;
    final int signIndex = (moonLong / 30.0).floor() % 12;
    const signs = [
      'Áries ♈', 'Touro ♉', 'Gêmeos ♊', 'Câncer ♋', 
      'Leão ♌', 'Virgem ♍', 'Libra ♎', 'Escorpião ♏', 
      'Sagitário ♐', 'Capricórnio ♑', 'Aquário ♒', 'Peixes ♓'
    ];
    return signs[signIndex];
  }

  String _getBiome(double lat, double lon) {
    if (lat >= -26.5 && lat <= -24.0 && lon >= -50.0 && lon <= -48.0) {
      return 'Floresta de Araucárias / Mata Atlântica';
    }
    
    final absLat = lat.abs();
    
    if (absLat > 60.0) {
      return 'Tundra / Taiga ou Deserto Polar';
    }
    if (absLat > 35.0 && absLat <= 60.0) {
      return 'Clima Temperado (Floresta Decídua / Campos)';
    }
    if (absLat > 18.0 && absLat <= 35.0) {
      if (lat >= 15.0 && lat <= 30.0 && lon >= -15.0 && lon <= 40.0) {
        return 'Deserto do Saara / Árido';
      }
      if (lat >= 15.0 && lat <= 32.0 && lon >= 35.0 && lon <= 60.0) {
        return 'Deserto Árido / Arbustivo';
      }
      if (lat >= -30.0 && lat <= -18.0 && lon >= 115.0 && lon <= 145.0) {
        return 'Deserto Australiano / Outback';
      }
      return 'Zonas Subtropicais (Campos / Florestas Secas)';
    }
    if (lat >= -15.0 && lat <= 5.0 && lon >= -80.0 && lon <= -35.0) {
      return 'Floresta Tropical Úmida (Amazônia)';
    }
    if (lat >= -5.0 && lat <= 5.0 && lon >= 10.0 && lon <= 30.0) {
      return 'Floresta Tropical Úmida (Congo)';
    }
    if (lat >= -10.0 && lat <= 20.0 && lon >= 95.0 && lon <= 140.0) {
      return 'Floresta Tropical / Monções';
    }
    
    return 'Savana Tropical / Cerrado';
  }

  int _estimateAQI() {
    final hour = _currentTime.hour;
    if (hour >= 7 && hour <= 10) return 42;
    if (hour >= 17 && hour <= 20) return 48;
    return 24;
  }

  String _getAQIDescription(int aqi) {
    if (aqi <= 50) return 'Bom';
    if (aqi <= 100) return 'Moderado';
    return 'Inadequado';
  }

  String _estimateVisibility() {
    final desc = _weatherDesc.toLowerCase();
    if (desc.contains('chuva') || desc.contains('rain')) return '6.0 km';
    if (desc.contains('nevoeiro') || desc.contains('fog')) return '1.5 km';
    if (desc.contains('nublado') || desc.contains('cloudy')) return '10.0 km';
    return '16.0 km';
  }

  String _getWindDirectionLabel(double degree) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final idx = ((degree + 22.5) % 360 / 45).floor();
    return directions[idx.clamp(0, 7)];
  }

  String _getFormattedLocation() {
    if (_cityName == 'Curitiba, BR') {
      return 'Curitiba, Paraná, Brasil';
    }
    return _cityName;
  }

  String _getSunZodiacSign(DateTime date) {
    final month = date.month;
    final day = date.day;
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Áries ♈';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Touro ♉';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gêmeos ♊';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Câncer ♋';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leão ♌';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgem ♍';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra ♎';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'Escorpião ♏';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Sagitário ♐';
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'Capricórnio ♑';
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquário ♒';
    return 'Peixes ♓';
  }

  Widget _buildExtendedInfoRow({
    required IconData icon,
    required String value,
    required Color textColor,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            child: Center(
              child: Icon(
                icon,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: child,
      );
    }
    return child;
  }

  String _getTimezoneOffsetLabel() {
    final offset = _currentTime.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.abs() % 60;
    final sign = hours >= 0 ? '+' : '-';
    return 'UTC$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _handleSunMoonTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _tapTimestamps.add(now);
    
    _tapTimestamps.removeWhere((ts) => now - ts > 600);

    if (_tapTimestamps.length >= 3) {
      _tapTimestamps.clear();
      _tapTimer?.cancel();
      setState(() {
        final nextMode = ContextHeader.isPanelOpenNotifier.value == HeaderMode.none
            ? HeaderMode.timeSpace
            : HeaderMode.none;
        ContextHeader.isPanelOpenNotifier.value = nextMode;
        _showPanel = (nextMode == HeaderMode.timeSpace);
        if (nextMode == HeaderMode.timeSpace) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
      return;
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 220), () {
      if (_tapTimestamps.length == 1) {
        _togglePanel();
      } else if (_tapTimestamps.length == 2) {
        final newMode = Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
        ThemeManager.toggleTheme(newMode);
      }
      _tapTimestamps.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    final sunColor = Colors.orangeAccent;
    final moonColor = Colors.white;
    final moonInfo = _getMoonPhaseInfo();

    final moonAge = (DateTime.now().toUtc().difference(DateTime.utc(2000, 1, 6, 18, 14)).inMilliseconds / (1000 * 60 * 60 * 24)) % 29.530588853;
    final moonBrightness = (1.0 - math.cos((moonAge / 29.530588853) * 2 * math.pi)) / 2.0 * 100.0;
    final moonSign = _getMoonZodiacSign(_currentTime);
    final sunSign = _getSunZodiacSign(_currentTime);
    final biome = _getBiome(_userLat, _userLon);
    final aqi = _estimateAQI();
    final aqiDesc = _getAQIDescription(aqi);
    final visibility = _estimateVisibility();
    final windDirectionLabel = _getWindDirectionLabel(_windDirection);

    final String tempValueStr = _isFahrenheit
        ? '${(_weatherTempCelsius * 9.0 / 5.0 + 32.0).toStringAsFixed(0)}°F (Sensação: ${(_apparentTemp * 9.0 / 5.0 + 32.0).toStringAsFixed(1)}°F)'
        : '${_weatherTempCelsius.toStringAsFixed(0)}°C (Sensação: ${_apparentTemp.toStringAsFixed(1)}°C)';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top by default
        children: [
          // 1. Sun/Moon Icon (Top Left) - slides down when open
          AnimatedPadding(
            padding: EdgeInsets.only(top: _showPanel ? 14.0 : 0.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: GestureDetector(
              onTap: _handleSunMoonTap,
              onSecondaryTap: _togglePanel,
              child: Tooltip(
                message: isDark ? 'Fase atual: ${moonInfo['name']}' : 'Dê dois cliques para alternar o tema',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? moonColor : sunColor).withOpacity(0.15),
                        blurRadius: _showPanel ? 12 : 4,
                        spreadRadius: _showPanel ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDark ? moonInfo['icon'] : Icons.wb_sunny_rounded,
                    size: 28,
                    color: isDark ? moonColor : sunColor,
                  ),
                ),
              ),
            ),
          ),
          // 2. Interactive Info Panel (Revealed next to Sun/Moon)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              if (_animationController.value == 0.0 && !_showPanel) {
                return const SizedBox.shrink();
              }
              
              // Calculate responsive slide offset
              final Offset offset;
              if (_showPanel) {
                final double progress = Curves.easeOutCubic.transform(_animationController.value);
                offset = Offset(progress - 1.0, 0.0);
              } else {
                final double progress = Curves.easeInCubic.transform(1.0 - _animationController.value);
                offset = Offset(progress, 0.0);
              }

              return Expanded(
                child: ClipRect(
                  child: FadeTransition(
                    opacity: _animationController,
                    child: FractionalTranslation(
                      translation: offset,
                      child: child!,
                    ),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Line 1: Real-time clock with seconds + Timezone Label + Expand/Collapse Button
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.center,
                       children: [
                         InkWell(
                           onTap: () => LauncherService.openClockApp(),
                           borderRadius: BorderRadius.circular(6),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             crossAxisAlignment: CrossAxisAlignment.center,
                             children: [
                               SizedBox(
                                 width: 18,
                                 child: Center(
                                   child: Icon(
                                     Icons.access_time_rounded,
                                     size: 14,
                                     color: theme.colorScheme.primary,
                                   ),
                                 ),
                               ),
                               const SizedBox(width: 6),
                               Text(
                                 "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}",
                                 style: TextStyle(
                                   fontSize: 13,
                                   fontWeight: FontWeight.bold,
                                   color: textColor,
                                   letterSpacing: 0.5,
                                   height: 1.1,
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 16),
                         if (_isExtended) ...[
                           Icon(
                             Icons.public_rounded,
                             size: 14,
                             color: theme.colorScheme.primary.withOpacity(0.8),
                           ),
                           const SizedBox(width: 6),
                           Text(
                             _getTimezoneOffsetLabel(),
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               color: textColor,
                               height: 1.1,
                             ),
                           ),
                         ] else ...[
                           Icon(
                             moonInfo['icon'],
                             size: 14,
                             color: isDark ? moonColor.withOpacity(0.9) : theme.colorScheme.primary.withOpacity(0.8),
                           ),
                           const SizedBox(width: 6),
                           Text(
                             moonInfo['name'],
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.w600,
                               color: textColor,
                               height: 1.1,
                             ),
                           ),
                         ],
                         const Spacer(),
                         GestureDetector(
                           onTap: () {
                             final bool targetExtendedState = !_isExtended;
                             if (targetExtendedState) {
                               // Close map overlays if opening extended state
                               VirtualTopography.closeOverlaysNotifier.value = 
                                   !VirtualTopography.closeOverlaysNotifier.value;
                             }
                             setState(() {
                               _isExtended = targetExtendedState;
                               ContextHeader.isExtendedNotifier.value = targetExtendedState;
                             });
                           },
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: BoxDecoration(
                               color: theme.colorScheme.primary.withOpacity(0.12),
                               shape: BoxShape.circle,
                             ),
                             child: Icon(
                               _isExtended ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                               size: 13,
                               color: theme.colorScheme.primary,
                             ),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 6),

                     if (_isExtended) ...[
                       // Extended Layout - natural wrapping, one item per line, custom ordered
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           // 1. Calendar
                           InkWell(
                             onTap: _cycleCalendar,
                             borderRadius: BorderRadius.circular(6),
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.center,
                               children: [
                                 SizedBox(
                                   width: 18,
                                   child: Center(
                                     child: _getCalendarSymbolWidget(context),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     _getCalendarDateString(),
                                     style: TextStyle(
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                       color: textColor,
                                       height: 1.1,
                                     ),
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 4),

                           // 2. Solar Cycle (Nascer: ... • Pôr: ...)
                           _buildExtendedInfoRow(
                             icon: Icons.wb_twilight_rounded,
                             value: 'Nascer: $_sunriseTime  •  Pôr: $_sunsetTime',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 3. Location
                           _buildExtendedInfoRow(
                             icon: Icons.location_on_rounded,
                             value: _getFormattedLocation(),
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 4. Biome
                           _buildExtendedInfoRow(
                             icon: Icons.forest_rounded,
                             value: biome,
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 5. Coordinates (formatted as: Sul: X°, Oeste: Y°)
                           _buildExtendedInfoRow(
                             icon: Icons.explore_rounded,
                             value: '${_userLat < 0 ? 'Sul' : 'Norte'}: ${_userLat.abs().toStringAsFixed(5)}°, ${_userLon < 0 ? 'Oeste' : 'Leste'}: ${_userLon.abs().toStringAsFixed(5)}°',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 6. GPS Accuracy (Precisão GPS ± X m)
                           _buildExtendedInfoRow(
                             icon: Icons.gps_fixed_rounded,
                             value: 'Precisão GPS ± ${_gpsAccuracy.toStringAsFixed(1)} m',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 7. Altitude (X m de Altitude)
                           _buildExtendedInfoRow(
                             icon: Icons.landscape_rounded,
                             value: '${_userAltitude.toStringAsFixed(1)} m de Altitude',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 8. Temperature (Unit toggleable on tap)
                           _buildExtendedInfoRow(
                             icon: Icons.thermostat_rounded,
                             value: tempValueStr,
                             textColor: textColor,
                             theme: theme,
                             onTap: () {
                               setState(() {
                                 _isFahrenheit = !_isFahrenheit;
                               });
                             },
                           ),
                           const SizedBox(height: 4),

                           // 9. Weather Description (Clima)
                           _buildExtendedInfoRow(
                             icon: _getWeatherIconData() ?? Icons.wb_sunny_rounded,
                             value: _weatherDesc,
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 10. Wind
                           _buildExtendedInfoRow(
                             icon: Icons.air_rounded,
                             value: 'Vento: ${_windSpeed.toStringAsFixed(1)} km/h ($windDirectionLabel)',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 11. Humidity
                           _buildExtendedInfoRow(
                             icon: Icons.water_drop_rounded,
                             value: '$_relativeHumidity% de Humidade Relativa do Ar',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 12. Air Quality
                           _buildExtendedInfoRow(
                             icon: Icons.science_rounded,
                             value: '$aqi AQI Qualidade do ar $aqiDesc',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 13. Pressure
                           _buildExtendedInfoRow(
                             icon: Icons.speed_rounded,
                             value: '${_surfacePressure.toStringAsFixed(0)} hPa de Pressão Atmosférica',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 14. UV Index
                           _buildExtendedInfoRow(
                             icon: Icons.wb_sunny_outlined,
                             value: '${_uvIndex.toStringAsFixed(1)} índice de UV máximo',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 15. Visibility
                           _buildExtendedInfoRow(
                             icon: Icons.visibility_rounded,
                             value: '$visibility de Visibilidade',
                             textColor: textColor,
                             theme: theme,
                           ),
                           const SizedBox(height: 4),

                           // 16. Moon Phase & Zodiac Signs
                           _buildExtendedInfoRow(
                             icon: moonInfo['icon'],
                             value: '${moonInfo['symbol']} ${moonInfo['name']} (${moonBrightness.toStringAsFixed(1)}% iluminada) • Signo da Lua: $moonSign • Signo Solar: $sunSign',
                             textColor: textColor,
                             theme: theme,
                           ),
                         ],
                       ),
                     ] else ...[
                       // Line 2: Date with Calendar cycle support
                       InkWell(
                         onTap: _cycleCalendar,
                         borderRadius: BorderRadius.circular(6),
                         child: Padding(
                           padding: const EdgeInsets.symmetric(vertical: 2.0),
                           child: Row(
                             crossAxisAlignment: CrossAxisAlignment.center,
                             children: [
                               SizedBox(
                                 width: 18,
                                 child: Center(
                                   child: _getCalendarSymbolWidget(context),
                                 ),
                               ),
                               const SizedBox(width: 6),
                               Expanded(
                                 child: Text(
                                   _getCalendarDateString(),
                                   style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                     color: textColor,
                                     height: 1.1,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 6),

                       // Line 3: Location and Weather (with dedicated icons)
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           SizedBox(
                             width: 18,
                             child: Center(
                               child: Icon(
                                 Icons.location_on_rounded,
                                 size: 14,
                                 color: theme.colorScheme.primary.withOpacity(0.8),
                               ),
                             ),
                           ),
                           const SizedBox(width: 6),
                            Text(
                              _onlyCityName,
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.w600,
                               color: textColor,
                               height: 1.1,
                             ),
                           ),
                           const SizedBox(width: 12),
                           Icon(
                             Icons.thermostat_rounded,
                             size: 14,
                             color: theme.colorScheme.primary.withOpacity(0.8),
                           ),
                           const SizedBox(width: 2),
                           Text(
                             _weatherTemp,
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               color: textColor,
                               height: 1.1,
                             ),
                           ),
                           const SizedBox(width: 12),
                           Icon(
                             _getWeatherIconData() ?? Icons.wb_sunny_rounded,
                             size: 14,
                             color: theme.colorScheme.primary.withOpacity(0.8),
                           ),
                           const SizedBox(width: 2),
                           Expanded(
                             child: Text(
                               _weatherDesc,
                               style: TextStyle(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w600,
                                 color: textColor,
                                 height: 1.1,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                     ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSymbolPainter extends CustomPainter {
  final int index;
  final Color color;

  _CalendarSymbolPainter(this.index, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final cx = size.width / 2;
    final cy = size.height / 2;

    if (index == 0) {
      // Gregorian: Latin Cross
      canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 6), paint);
      canvas.drawLine(Offset(cx - 3.5, cy - 2), Offset(cx + 3.5, cy - 2), paint);
    } else if (index == 1) {
      // Chinese: Yin Yang
      canvas.drawCircle(Offset(cx, cy), 6, paint);
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: 6),
        -math.pi / 2,
        math.pi,
        true,
        fillPaint,
      );
      // Draw small inner opposite colored dots
      canvas.drawCircle(Offset(cx, cy - 3), 1.2, Paint()..color = Colors.black..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(cx, cy + 3), 1.2, Paint()..color = color..style = PaintingStyle.fill);
    } else if (index == 2) {
      // Hebrew: Star of David
      final path = Path();
      // Triangle 1
      path.moveTo(cx, cy - 6);
      path.lineTo(cx + 5.2, cy + 3);
      path.lineTo(cx - 5.2, cy + 3);
      path.close();
      // Triangle 2
      path.moveTo(cx, cy + 6);
      path.lineTo(cx + 5.2, cy - 3);
      path.lineTo(cx - 5.2, cy - 3);
      path.close();
      canvas.drawPath(path, paint);
    } else if (index == 3) {
      // Hijri: Crescent Moon
      final moonPath = Path();
      moonPath.addArc(Rect.fromCircle(center: Offset(cx - 1.5, cy), radius: 5.5), -1.2, 2.4);
      moonPath.arcTo(Rect.fromCircle(center: Offset(cx + 1.0, cy), radius: 4.5), 1.6, -3.2, false);
      moonPath.close();
      canvas.drawPath(moonPath, paint..style = PaintingStyle.fill);

      // Star
      final starPaint = Paint()
        ..color = color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx + 3.5, cy - 2), Offset(cx + 3.5, cy + 1), starPaint);
      canvas.drawLine(Offset(cx + 2.0, cy - 0.5), Offset(cx + 5.0, cy - 0.5), starPaint);
    } else {
      // index == 4: Mayan Kin (Sun glyph)
      canvas.drawCircle(Offset(cx, cy), 6, paint);
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), paint);
      canvas.drawLine(Offset(cx, cy - 3), Offset(cx, cy + 3), paint);
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - 2.5, cy - 2.5), 0.8, dotPaint);
      canvas.drawCircle(Offset(cx + 2.5, cy - 2.5), 0.8, dotPaint);
      canvas.drawCircle(Offset(cx - 2.5, cy + 2.5), 0.8, dotPaint);
      canvas.drawCircle(Offset(cx + 2.5, cy + 2.5), 0.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarSymbolPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.color != color;
}
