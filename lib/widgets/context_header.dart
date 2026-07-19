import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_manager.dart';
import '../services/launcher_service.dart';

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

  // Notifier to notify parent widgets when the info details panel is open or closed
  static final ValueNotifier<bool> isPanelOpenNotifier = ValueNotifier(false);

  @override
  State<ContextHeader> createState() => _ContextHeaderState();
}

class _ContextHeaderState extends State<ContextHeader> with SingleTickerProviderStateMixin {
  late DateTime _currentTime;
  late Timer _timer;
  String _weatherTemp = '--';
  String _weatherDesc = '--';
  String _cityName = 'Curitiba, BR'; // Shown while GPS loads; replaced by cache or real location
  double _userLat = -25.4284;
  double _userLon = -49.2733;
  bool _showPanel = false;
  int _calendarSystemIndex = 0; // 0: Gregorian, 1: Chinese, 2: Hebrew, 3: Hijri
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
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 1. Load cached city name instantly (no delay)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('portal_city_name');
    final cachedLat = prefs.getDouble('portal_last_lat');
    final cachedLon = prefs.getDouble('portal_last_lon');
    if (cached != null && mounted) {
      setState(() => _cityName = cached);
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
        final city = address?['city'] ??
            address?['town'] ??
            address?['village'] ??
            address?['municipality'] ??
            address?['county'] ??
            'GPS';
        final country = address?['country_code']?.toString().toUpperCase() ?? '';
        final name = '$city, $country';
        if (mounted) {
          setState(() => _cityName = name);
        }
        // Cache for next launch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('portal_city_name', name);
        await prefs.setDouble('portal_last_lat', lat);
        await prefs.setDouble('portal_last_lon', lon);
      }
    } catch (_) {
      // Keep whatever we already have (cache or default)
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&timezone=auto');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current']['temperature_2m'];
        final code = data['current']['weather_code'];

        if (mounted) {
          setState(() {
            _weatherTemp = '${(temp as num).toStringAsFixed(0)}°C';
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
      _showPanel = !_showPanel;
      if (_showPanel) {
        ContextHeader.isPanelOpenNotifier.value = true;
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _showPanel) {
            _animationController.forward();
          }
        });
      } else {
        _animationController.reverse().then((_) {
          if (!_showPanel) {
            ContextHeader.isPanelOpenNotifier.value = false;
          }
        });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sunColor = Colors.orangeAccent;
    final moonColor = Colors.white;
    final moonInfo = _getMoonPhaseInfo();

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
              onTap: _togglePanel,
              onDoubleTap: () {
                final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                ThemeManager.toggleTheme(newMode);
              },
              onSecondaryTap: _togglePanel,
              child: Tooltip(
                message: isDark ? 'Fase atual: ${moonInfo['name']}' : 'Dê dois cliques para alternar o tema',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white, // White background in light mode
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
                // Entry: Slide from left (-1.0) to center (0.0)
                final double progress = Curves.easeOutCubic.transform(_animationController.value);
                offset = Offset(progress - 1.0, 0.0);
              } else {
                // Exit: Slide from center (0.0) to right (1.0)
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
                  color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5), // Color matching other bars
                  borderRadius: BorderRadius.circular(24), // BorderRadius matching other bars
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.12), // Border matching other bars
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // Line 1: Real-time clock with seconds + timezone + Moon Phase
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
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 0.5,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
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
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

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
                                  color: theme.colorScheme.onSurface,
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
                          _cityName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
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
                            color: theme.colorScheme.onSurface,
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
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
