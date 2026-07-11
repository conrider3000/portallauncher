import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme_manager.dart';

class MultiCalendarHelper {
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

class _ContextHeaderState extends State<ContextHeader> {
  late DateTime _currentTime;
  late Timer _timer;
  String _weatherTemp = '24°C';
  String _weatherDesc = 'Céu Limpo';
  bool _showPanel = false;
  int _calendarSystemIndex = 0; // 0: Gregorian, 1: Chinese, 2: Hebrew, 3: Hijri

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    _fetchWeather();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=-23.5489&longitude=-46.6388&current=temperature_2m,weather_code&timezone=America%2FSao_Paulo');
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
      ContextHeader.isPanelOpenNotifier.value = _showPanel;
    });
  }

  void _cycleCalendar() {
    setState(() {
      _calendarSystemIndex = (_calendarSystemIndex + 1) % 4;
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
      case 0:
      default:
        return MultiCalendarHelper.getGregorianDate(_currentTime);
    }
  }

  Widget _getCalendarSymbolWidget(BuildContext context) {
    final theme = Theme.of(context);
    String symbol = '🌐';
    Color color = theme.colorScheme.secondary;
    
    switch (_calendarSystemIndex) {
      case 1:
        symbol = '☯';
        color = Colors.redAccent;
        break;
      case 2:
        symbol = '✡';
        color = Colors.blueAccent;
        break;
      case 3:
        symbol = '☪';
        color = Colors.green;
        break;
      case 0:
      default:
        symbol = '✝';
        color = Colors.amber;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 15,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        'icon': Icons.brightness_1_rounded, // Full moon circle
        'name': 'Lua Cheia',
      };
    } else if (age > 16.5 && age < 27.5) {
      return {
        'icon': Icons.brightness_3_rounded, // Crescent/Minguante
        'name': 'Lua Minguante',
      };
    } else if (age > 2.0 && age < 13.0) {
      return {
        'icon': Icons.brightness_3_rounded, // Crescent/Crescente
        'name': 'Lua Crescente',
      };
    } else {
      return {
        'icon': Icons.brightness_2_rounded, // Outline/Nova
        'name': 'Lua Nova',
      };
    }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sun/Moon Icon (Top Left)
          GestureDetector(
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
                  color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? moonColor : sunColor).withOpacity(0.2),
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
          // 2. Interactive Info Panel (Revealed next to Sun/Moon)
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showPanel
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Line 1: Real-time clock with seconds
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
                                  children: [
                                    _getCalendarSymbolWidget(context),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getCalendarDateString(),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
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

                            // Line 3: Location and Weather
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "São Paulo, BR • $_weatherTemp, $_weatherDesc • ${moonInfo['name']}",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
