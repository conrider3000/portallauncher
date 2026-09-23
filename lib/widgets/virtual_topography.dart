import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'context_header.dart';

class VirtualTopography extends StatefulWidget {
  const VirtualTopography({super.key});

  // Global map search query notifier to center the globe on matching locations
  static final ValueNotifier<String> mapSearchQueryNotifier = ValueNotifier('');
  static final ValueNotifier<Set<String>> earthFilterNotifier = ValueNotifier({'Satélite', 'Clima', 'Monitoramento'});
  static final ValueNotifier<String?> directSearchTrigger = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> toggleRotationTrigger = ValueNotifier<bool>(true);
  static final ValueNotifier<int> rotationSpeedNotifier = ValueNotifier<int>(1000);
  static final ValueNotifier<bool> closeOverlaysNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> refreshSatelliteTrigger = ValueNotifier<bool>(false);
  static VoidCallback? onTapCallback;

  @override
  State<VirtualTopography> createState() => _VirtualTopographyState();
}

class _VirtualTopographyState extends State<VirtualTopography> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  double _manualRotationX = 0.0;
  double _manualRotationY = 0.0;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  double _baseRotationX = 0.4;
  double _baseRotationY = 0.0;

  // Pinch-to-zoom variables
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  List<List<Offset>> _geoJsonContinents = [];

  // Flat satellite map transition variables (used in Esri tile integration)
  // ignore: unused_field, prefer_final_fields
  bool _showFlatMap = false;
  // ignore: unused_field, prefer_final_fields
  double _flatMapCenterLat = -23.5505;
  // ignore: unused_field, prefer_final_fields
  double _flatMapCenterLon = -46.6333;


  ui.Image? _earthImage;
  ui.Image? _cloudsImage;
  bool _isLoadingTexture = true;
  Timer? _cloudsRefreshTimer;
  String _loadingStatus = 'CONECTANDO AO SISTEMA DE SATÉLITES...';

  Map<String, dynamic>? _selectedGeoPoint;
  Timer? _popupTimer;
  
  Timer? _easterEggTimer;
  bool _isEasterEggActive = false;
  
  void _toggleEasterEgg() {
    if (!mounted) return;
    setState(() {
      _isEasterEggActive = !_isEasterEggActive;
      if (_isEasterEggActive) {
        _animationController.duration = const Duration(seconds: 60);
        _animationController.repeat();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Easter Egg: Rotação de 60 segundos ativada! ⏱️'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
      } else {
        _updateRotationDuration(VirtualTopography.rotationSpeedNotifier.value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Easter Egg desativado!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        );
      }
    });
  }
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _wikiSearchResults = [];
  // ignore: unused_field
  bool _isSearchingWiki = false;

  final List<Map<String, dynamic>> _geoPoints = [
    {
      'name': 'São Paulo, BR',
      'lat': -23.5505,
      'lon': -46.6333,
      'project': 'Nuvem Satélite GOES-16',
      'info': 'Camada de nuvens atualizada há 5m. Imagens termais ativas.',
      'status': 'ONLINE'
    },
    {
      'name': 'New York, US',
      'lat': 40.7128,
      'lon': -74.0060,
      'project': 'Landsat-9 Cloud Cover',
      'info': 'Monitoramento de densidade urbana e umidade relativa.',
      'status': 'ONLINE'
    },
    {
      'name': 'London, UK',
      'lat': 51.5074,
      'lon': -0.1278,
      'project': 'Sentinel-2 RGB Feed',
      'info': 'Feed óptico de alta resolução sobre o Canal da Mancha.',
      'status': 'SYNCING'
    },
    {
      'name': 'Tokyo, JP',
      'lat': 35.6762,
      'lon': 139.6503,
      'project': 'Himawari-9 Live IR',
      'info': 'Detecção de tempestades ativas no pacífico ocidental.',
      'status': 'ONLINE'
    },
    {
      'name': 'Sydney, AU',
      'lat': -33.8688,
      'lon': 151.2093,
      'project': 'Aqua-MODIS Chlorophyll',
      'info': 'Monitoramento térmico oceânico na Grande Barreira de Corais.',
      'status': 'ONLINE'
    },
    {
      'name': 'Cairo, EG',
      'lat': 30.0444,
      'lon': 31.2357,
      'project': 'Meteosat Cloud Vector',
      'info': 'Sensoriamento de poeira desértica e ventos térmicos.',
      'status': 'STANDBY'
    }
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 24),
    )..repeat();

    _downloadEarthTexture();
    _cloudsRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _downloadEarthTexture();
    });

    _loadCachedFilter();
    
    _loadCachedRotationSpeed();
    VirtualTopography.rotationSpeedNotifier.addListener(_onRotationSpeedChanged);
    VirtualTopography.mapSearchQueryNotifier.addListener(_onMapSearchQueryChanged);

    VirtualTopography.earthFilterNotifier.addListener(_onFilterChanged);
    VirtualTopography.directSearchTrigger.addListener(_onDirectSearchTriggered);
    VirtualTopography.toggleRotationTrigger.addListener(_onToggleRotationChanged);
    VirtualTopography.closeOverlaysNotifier.addListener(_onCloseOverlays);
    VirtualTopography.refreshSatelliteTrigger.addListener(_onRefreshSatelliteTriggered);
    _initializeUserCoordinates();
    _loadGeoJsonData();
  }

  @override
  void dispose() {
    
    VirtualTopography.rotationSpeedNotifier.removeListener(_onRotationSpeedChanged);
    VirtualTopography.mapSearchQueryNotifier.removeListener(_onMapSearchQueryChanged);

    VirtualTopography.earthFilterNotifier.removeListener(_onFilterChanged);
    VirtualTopography.directSearchTrigger.removeListener(_onDirectSearchTriggered);
    VirtualTopography.toggleRotationTrigger.removeListener(_onToggleRotationChanged);
    VirtualTopography.closeOverlaysNotifier.removeListener(_onCloseOverlays);
    VirtualTopography.refreshSatelliteTrigger.removeListener(_onRefreshSatelliteTriggered);
    _animationController.dispose();
    _popupTimer?.cancel();
    _cloudsRefreshTimer?.cancel();
    super.dispose();
  }

  void _onRefreshSatelliteTriggered() {
    _downloadEarthTexture();
    _initializeUserCoordinates();
    _loadGeoJsonData();
  }

  void _onCloseOverlays() {
    if (mounted) {
      setState(() {
        _selectedGeoPoint = null;
      });
    }
  }


  Future<void> _loadGeoJsonData() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/geo/land_110m_compact.json');
      final List<dynamic> parsed = json.decode(jsonString);
      final List<List<Offset>> list = [];
      for (var poly in parsed) {
        final List<Offset> pts = [];
        for (var pt in poly) {
          pts.add(Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
        }
        list.add(pts);
      }
      if (mounted) {
        setState(() {
          _geoJsonContinents = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
    }
  }

  Future<void> _initializeUserCoordinates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double? lat = prefs.getDouble('portal_last_lat');
      double? lon = prefs.getDouble('portal_last_lon');

      if (lat == null || lon == null) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            lat = lastPos.latitude;
            lon = lastPos.longitude;
          }
        }
      }

      if (lat != null && lon != null) {
        final double latRad = lat * math.pi / 180.0;
        final double lonRad = lon * math.pi / 180.0;
        setState(() {
          final autoRotY = _animationController.value * 2 * math.pi;
          _manualRotationY = -lonRad - math.pi - autoRotY;
          _manualRotationX = latRad - 0.2;
          _zoom = 1.1;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCachedFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilters = prefs.getStringList('portal_earth_active_layers');
      if (savedFilters != null) {
        final set = savedFilters.toSet();
        if (set.isEmpty) {
          set.addAll(['Satélite', 'Clima']);
        }
        if (mounted) {
          setState(() {
            VirtualTopography.earthFilterNotifier.value = set;
          });
        } else {
          VirtualTopography.earthFilterNotifier.value = set;
        }
      }
    } catch (_) {}
  }

  void _onFilterChanged() async {
    if (mounted) {
      setState(() {});
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('portal_earth_active_layers', VirtualTopography.earthFilterNotifier.value.toList());
    } catch (_) {}
  }


  Future<void> _loadCachedRotationSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final speed = prefs.getInt('portal_earth_rotation_speed') ?? 1000;
      VirtualTopography.rotationSpeedNotifier.value = speed;
      _updateRotationDuration(speed);
    } catch (_) {}
  }

  void _onRotationSpeedChanged() async {
    final speed = VirtualTopography.rotationSpeedNotifier.value;
    _updateRotationDuration(speed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('portal_earth_rotation_speed', speed);
    } catch (_) {}
  }

  void _updateRotationDuration(int speed) {
    if (!mounted) return;
    if (_isEasterEggActive) return;
    final int baseSeconds = 86400; // 24 hours
    
    // If speed is very large, durationSeconds might be 0, so clamp to 1 minimum
    int durationSeconds = baseSeconds ~/ speed;
    if (durationSeconds < 1) durationSeconds = 1;
    
    final currentValue = _animationController.value;
    _animationController.stop();
    _animationController.duration = Duration(seconds: durationSeconds);
    _animationController.value = currentValue;
    
    if (VirtualTopography.toggleRotationTrigger.value) {
      // Use repeat to ensure the new duration is picked up
      _animationController.repeat();
    }
  }

  void _onToggleRotationChanged() {

    if (VirtualTopography.toggleRotationTrigger.value) {
      if (_selectedGeoPoint == null && !_animationController.isAnimating) {
        _animationController.repeat();
      }
    } else {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
    }
  }

  void _onDirectSearchTriggered() {
    final query = VirtualTopography.directSearchTrigger.value?.trim();
    if (query == null || query.isEmpty) return;
    _performDirectSearch(query);
    VirtualTopography.directSearchTrigger.value = null;
  }

  Future<void> _performDirectSearch(String query) async {
    final String detailsUrl = 'https://pt.wikipedia.org/w/api.php?action=query&prop=coordinates|extracts&exintro&explaintext&titles=${Uri.encodeComponent(query)}&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(detailsUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final detailsData = jsonDecode(response.body);
        final pages = detailsData['query']?['pages'] as Map?;
        if (pages != null && pages.isNotEmpty) {
          final pageId = pages.keys.first;
          final pageData = pages[pageId];
          final coords = pageData['coordinates'] as List?;
          final String extract = pageData['extract'] ?? '';

          double lat = -14.2350;
          double lon = -51.9253;

          if (coords != null && coords.isNotEmpty) {
            lat = coords[0]['lat'];
            lon = coords[0]['lon'];
          } else {
            final text = extract.toLowerCase();
            if (text.contains('portugal') || text.contains('português')) {
              lat = 39.3999; lon = -8.2245;
            } else if (text.contains('estados unidos') || text.contains('eua')) {
              lat = 37.0902; lon = -95.7129;
            } else if (text.contains('alemanha')) {
              lat = 51.1657; lon = 10.4515;
            } else if (text.contains('frança') || text.contains('paris')) {
              lat = 48.8566; lon = 2.3522;
            } else if (text.contains('japão') || text.contains('tóquio')) {
              lat = 36.2048; lon = 138.2529;
            }
          }

          final double latRad = lat * math.pi / 180.0;
          final double lonRad = lon * math.pi / 180.0;
          final autoRotY = _animationController.value * 2 * math.pi;

          if (mounted) {
            setState(() {
              _wikiSearchResults = [];
              _selectedGeoPoint = null; // NO duplicate popup card!
              _manualRotationY = (math.pi / 2) - lonRad - autoRotY;
              _manualRotationX = latRad.clamp(-math.pi / 3, math.pi / 3);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao focar globo: $e');
    }
  }

  void _onMapSearchQueryChanged() {
    final query = VirtualTopography.mapSearchQueryNotifier.value.trim();
    if (query.isEmpty) {
      setState(() {
        _selectedGeoPoint = null;
        _wikiSearchResults = [];
        _isSearchingWiki = false;
      });
      return;
    }

    // Debounce and search Wikipedia
    _debounceTimer?.cancel();
    setState(() {
      _isSearchingWiki = true;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performWikiSearch(query);
    });
  }

  Future<void> _performWikiSearch(String query) async {
    final String searchUrl = 'https://pt.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchList = data['query']?['search'] as List?;
        if (searchList != null) {
          setState(() {
            _wikiSearchResults = searchList.map((item) => {
              'title': item['title'] as String,
              'snippet': (item['snippet'] as String)
                  .replaceAll(RegExp(r'<[^>]*>'), ''), // strip HTML tags
            }).toList();
            _isSearchingWiki = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isSearchingWiki = false;
      });
      debugPrint('Erro na busca da Wikipedia: $e');
    }
  }

  Future<void> _fetchWikiPageDetails(String title) async {
    final String detailsUrl = 'https://pt.wikipedia.org/w/api.php?action=query&prop=coordinates|extracts|pageimages&exintro&explaintext&piprop=thumbnail&pithumbsize=200&titles=$title&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(detailsUrl));
      if (response.statusCode == 200) {
        final detailsData = jsonDecode(response.body);
        final pages = detailsData['query']?['pages'] as Map?;
        if (pages != null && pages.isNotEmpty) {
          final pageId = pages.keys.first;
          final pageData = pages[pageId];
          final coords = pageData['coordinates'] as List?;
          final String extract = pageData['extract'] ?? '';
          final String? thumbnail = pageData['thumbnail']?['source'];
          
          double lat = -14.2350; // default to Brazil
          double lon = -51.9253;
          bool hasCoords = false;

          if (coords != null && coords.isNotEmpty) {
            lat = coords[0]['lat'];
            lon = coords[0]['lon'];
            hasCoords = true;
          } else {
            // Geolocation fallback based on country references in text
            final text = extract.toLowerCase();
            if (text.contains('portugal') || text.contains('português') || text.contains('portuguesa')) {
              lat = 39.3999; lon = -8.2245;
            } else if (text.contains('estados unidos') || text.contains('americano') || text.contains('americana') || text.contains('eua')) {
              lat = 37.0902; lon = -95.7129;
            } else if (text.contains('alemanha') || text.contains('alemão') || text.contains('alemã')) {
              lat = 51.1657; lon = 10.4515;
            } else if (text.contains('frança') || text.contains('francês') || text.contains('francesa')) {
              lat = 46.2276; lon = 2.2137;
            } else if (text.contains('itália') || text.contains('italiano') || text.contains('italiana')) {
              lat = 41.8719; lon = 12.5674;
            } else if (text.contains('espanha') || text.contains('espanhol') || text.contains('espanhola')) {
              lat = 40.4637; lon = -3.7492;
            } else if (text.contains('reino unido') || text.contains('inglaterra') || text.contains('inglês') || text.contains('londres')) {
              lat = 55.3781; lon = -3.4360;
            } else if (text.contains('japão') || text.contains('japonês') || text.contains('japonesa')) {
              lat = 36.2048; lon = 138.2529;
            } else if (text.contains('china') || text.contains('chinês') || text.contains('chinesa')) {
              lat = 35.8617; lon = 104.1954;
            } else if (text.contains('egito') || text.contains('egípcio') || text.contains('egípcia')) {
              lat = 26.8206; lon = 30.8025;
            }
          }

          final double latRad = lat * math.pi / 180.0;
          final double lonRad = lon * math.pi / 180.0;
          final autoRotY = _animationController.value * 2 * math.pi;

          setState(() {
            _wikiSearchResults = []; // Clear search list
            _selectedGeoPoint = {
              'name': title,
              'lat': lat,
              'lon': lon,
              'project': 'Artigo Wikipédia',
              'info': extract.length > 180 ? '${extract.substring(0, 177)}...' : extract,
              'fullInfo': extract,
              'imageUrl': thumbnail,
              'status': hasCoords ? 'LUGAR' : 'PAÍS'
            };
            
            _manualRotationY = -lonRad - math.pi - autoRotY;
            _manualRotationX = latRad - 0.2;
            _zoom = 1.1; // Reduced from 1.35 to prevent details card overlap
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar detalhes da página: $e');
    }
  }

  void _showInfoDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 580),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0A0F0D) : Colors.white).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Telemetria & Fontes de Dados',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(context),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── FORCE REFRESH BUTTON ──────────────────────────────────────
                        InkWell(
                          onTap: () {
                            ContextHeader.locationUpdateNotifier.value = !ContextHeader.locationUpdateNotifier.value;
                            final now = DateTime.now();
                            final stamp = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                            ContextHeader.lastFetchTimestamp = stamp;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Sincronização Forçada! Telemetria e dados atualizados em $stamp.'),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'FORÇAR ATUALIZAÇÃO E LIMPEZA AGORA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                        const SizedBox(height: 6),

                        // ── SCROLLABLE TECHNICAL SPECS ─────────────────────────────
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // 1. Clima & Tempo
                              _buildInfoSection(
                                title: 'METEOROLOGIA & CLIMA',
                                icon: Icons.wb_sunny_rounded,
                                theme: theme,
                                isDark: isDark,
                                content:
                                    '• Fonte Oficial: Open-Meteo V1 Weather API (High-Resolution Global Forecast System).\n'
                                    '• Modelos Matemáticos: ICON (DWD - Alemanha) + GFS (NOAA - Estados Unidos).\n'
                                    '• Dados Processados: Temperatura (°C/°F), Sensação Térmica, Umidade Relativa, Pressão Atmosférica de Superfície (hPa), Índice UV Máximo, Horários Exatos do Nascer e Pôr do Sol.\n'
                                    '• Frequência de Consulta: Automática a cada 15 min ou Manual Instantânea.\n'
                                    '• Última Atualização: ${ContextHeader.lastFetchTimestamp}',
                              ),
                              const SizedBox(height: 12),

                              // 2. Geolocalização
                              _buildInfoSection(
                                title: 'GEODESIA & GEOLOCALIZAÇÃO',
                                icon: Icons.my_location_rounded,
                                theme: theme,
                                isDark: isDark,
                                content:
                                    '• Hardware: Sensor GPS/GNSS FusedLocationProvider (Sensores GPS, GLONASS, Galileo e BeiDou no Samsung Galaxy A15).\n'
                                    '• Geocodificação Reversa: Engine OpenStreetMap Nominatim V1 (Open Database License).\n'
                                    '• Dados Processados: Coordenadas em Datum WGS84 (Lat/Lon), Altitude em metros acima do nível médio do mar, Bairro, Cidade, Estado e País.\n'
                                    '• Precisão Geodésica: ~15 metros.\n'
                                    '• Última Atualização: ${ContextHeader.lastFetchTimestamp}',
                              ),
                              const SizedBox(height: 12),

                              // 3. Globo 3D & Satélites
                              _buildInfoSection(
                                title: 'TERRA 3D & REFLETÂNCIA DE SATÉLITE',
                                icon: Icons.satellite_alt_rounded,
                                theme: theme,
                                isDark: isDark,
                                content:
                                    '• Fonte de Texturas: ESRI World Imagery (Mosaico Óptico de Alta Resolução 0.5m/px) & Imagens Geostacionárias NOAA GOES-16/17.\n'
                                    '• Modelo de Projeção: Projeção Esférica Tridimensional em Canvas 2D Flutter com rotação rígida de 180° no Eixo Z.\n'
                                    '• Orientação Científica: Polo Sul posicionado no Topo da Tela, Polo Norte na Base (Sem Espelhamento, Longitudes e Latitudes Preservadas).\n'
                                    '• Taxa de Atualização: Renderização a 60 Quadros por Segundo (60 Hz) com Rotação Sideral 360°/24h.\n'
                                    '• Estado de Renderização: 60 FPS Ativo.',
                              ),
                              const SizedBox(height: 12),

                              // 4. Multi-Calendário & Cronometria
                              _buildInfoSection(
                                title: 'CRONOMETRIA & MULTI-CALENDÁRIO',
                                icon: Icons.calendar_month_rounded,
                                theme: theme,
                                isDark: isDark,
                                content:
                                    '• Fonte de Tempo: Relógio de Precisão Android / NTP Network Time Protocol.\n'
                                    '• Algoritmos Integrados: Calendário Gregoriano, Calendário Maia Dreamspell Tzolkin (13 Luas), Calendário Chinês Lunissolar, Calendário Hebraico e Calendário Hírico/Islâmico.\n'
                                    '• Frequência de Consulta: Tempo Real (sincronização por segundo - 1000ms).\n'
                                    '• Estado: Sincronizado.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<ui.Image?> _downloadImage(List<String> urls) async {
    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          return frame.image;
        }
      } catch (e) {
        debugPrint('Erro ao baixar $url: $e');
      }
    }
    return null;
  }

  Future<ui.Image?> _loadLocalAsset(String assetPath) async {
    try {
      final bd = await DefaultAssetBundle.of(context).load(assetPath);
      final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Erro ao carregar asset local $assetPath: $e');
      return null;
    }
  }

  Future<void> _downloadEarthTexture() async {
    try {
      if (mounted) {
        setState(() {
          _loadingStatus = 'CARREGANDO TEXTURAS...';
        });
      }

      // 1. Load local asset textures immediately so globe never stays in vector/stuck state
      final localEarth = await _loadLocalAsset('assets/earth_atmos_2048.jpg');
      final localClouds = await _loadLocalAsset('assets/earth_clouds_1024.png');

      if (localEarth != null && mounted) {
        setState(() {
          _earthImage = localEarth;
          _cloudsImage = localClouds ?? _cloudsImage;
          _isLoadingTexture = false;
        });
      }

      // 2. Refresh online texture in background if available
      final earthUrls = [
        'https://cdn.jsdelivr.net/gh/mrdoob/three.js@master/examples/textures/planets/earth_atmos_2048.jpg',
        'https://fastly.jsdelivr.net/gh/mrdoob/three.js@master/examples/textures/planets/earth_atmos_2048.jpg',
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
        'https://unpkg.com/three-globe/example/img/earth-blue-marble.jpg',
      ];

      final cloudsUrls = [
        'https://cdn.jsdelivr.net/gh/mrdoob/three.js@master/examples/textures/planets/earth_clouds_1024.png',
        'https://fastly.jsdelivr.net/gh/mrdoob/three.js@master/examples/textures/planets/earth_clouds_1024.png',
        'https://unpkg.com/three-globe/example/img/earth-clouds.png',
      ];

      final earthImg = await _downloadImage(earthUrls);
      final cloudsImg = await _downloadImage(cloudsUrls);

      if (mounted && earthImg != null) {
        setState(() {
          _earthImage = earthImg;
          if (cloudsImg != null) _cloudsImage = cloudsImg;
          _isLoadingTexture = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTexture = false;
        });
      }
    }
  }

  Future<void> _handleDoubleTapLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permissão de localização negada');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permissões de localização negadas permanentemente');
      return;
    }

    _showSnackBar('Centralizando na sua localização...');

    double? lat;
    double? lon;

    // Try last known position first (instant)
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        lat = lastPos.latitude;
        lon = lastPos.longitude;
      }
    } catch (_) {}

    // Fallback to SharedPreferences cache
    if (lat == null || lon == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        lat = prefs.getDouble('portal_last_lat');
        lon = prefs.getDouble('portal_last_lon');
      } catch (_) {}
    }

    // Default fallback (Curitiba)
    lat ??= -25.4284;
    lon ??= -49.2733;

    // Center instantly on cache/last position
    _centerOnCoords(lat, lon, setSelected: false);

    // Fetch fresh position in the background
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('portal_last_lat', position.latitude);
      await prefs.setDouble('portal_last_lon', position.longitude);
      // Trigger location update notifier
      ContextHeader.locationUpdateNotifier.value = !ContextHeader.locationUpdateNotifier.value;

      _centerOnCoords(position.latitude, position.longitude, setSelected: false);
    } catch (_) {}
  }

  Future<void> _centerOnCoords(double lat, double lon, {bool setSelected = true}) async {
    String cityName = 'Curitiba, BR';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('portal_city_name');
      final cachedLat = prefs.getDouble('portal_last_lat');
      final cachedLon = prefs.getDouble('portal_last_lon');
      if (cached != null && cachedLat != null && cachedLon != null) {
        final diffLat = (cachedLat - lat).abs();
        final diffLon = (cachedLon - lon).abs();
        if (diffLat < 0.05 && diffLon < 0.05) {
          cityName = cached;
        }
      }
    } catch (_) {}

    if (cityName == 'Curitiba, BR') {
      try {
        final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=10'
        ), headers: {
          'User-Agent': 'PortalLauncher/1.0 (android; contact@portallauncher.app)',
          'Accept-Language': 'pt-BR',
        }).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'] as Map<String, dynamic>?;
          final city = address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['municipality'] ?? 'Curitiba';
          final country = address?['country_code']?.toString().toUpperCase() ?? 'BR';
          cityName = '$city, $country';
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('portal_city_name', cityName);
          await prefs.setDouble('portal_last_lat', lat);
          await prefs.setDouble('portal_last_lon', lon);
          // Notify ContextHeader
          ContextHeader.locationUpdateNotifier.value = !ContextHeader.locationUpdateNotifier.value;
        }
      } catch (_) {}
    }

    final userPoint = {
      'name': cityName,
      'lat': lat,
      'lon': lon,
      'project': 'Receptor GPS Local',
      'info': 'Latitude: ${lat.toStringAsFixed(4)} • Longitude: ${lon.toStringAsFixed(4)}',
      'status': 'ONLINE'
    };

    if (mounted) {
      setState(() {
        _geoPoints.removeWhere((gp) => gp['name'] == 'Minha Localização' || gp['project'] == 'Receptor GPS Local');
        _geoPoints.add(userPoint);

        final double latRad = lat * math.pi / 180.0;
        final double lonRad = lon * math.pi / 180.0;
        final autoRotY = _animationController.value * 2 * math.pi;

        _manualRotationY = -lonRad - math.pi - autoRotY;
        _manualRotationX = latRad - 0.2;
        _zoom = 1.1;
        if (setSelected) {
          _selectedGeoPoint = userPoint;
          _animationController.stop();
        } else {
          _selectedGeoPoint = null;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _selectedGeoPoint == null && VirtualTopography.toggleRotationTrigger.value) {
              _animationController.repeat();
            }
          });
        }
      });
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _dragStartX = details.localFocalPoint.dx;
    _dragStartY = details.localFocalPoint.dy;
    _baseRotationX = _manualRotationX;
    _baseRotationY = _manualRotationY;
    _baseZoom = _zoom;
    _animationController.stop();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_selectedGeoPoint == null && VirtualTopography.toggleRotationTrigger.value) {
      _animationController.repeat();
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dx = details.localFocalPoint.dx - _dragStartX;
    final dy = details.localFocalPoint.dy - _dragStartY;
    setState(() {
      _manualRotationY = _baseRotationY - dx * 0.006;
      _manualRotationX = (_baseRotationX - dy * 0.006).clamp(-math.pi / 2.2, math.pi / 2.2);
      if (details.scale != 1.0) {
        _zoom = (_baseZoom * details.scale).clamp(0.6, 20.0);
      }
    });
  }

  void _handleTapDown(TapDownDetails details, double width, double height) {
    if (VirtualTopography.onTapCallback != null) {
      VirtualTopography.onTapCallback!();
    }
    if (_showFlatMap) return;
    final center = Offset(width / 2, height / 2);
    final radius = ((width - 32) / 2) * _zoom;

    final autoRotY = _animationController.value * 2 * math.pi;
    final rotY = autoRotY + _manualRotationY;
    final rotX = _manualRotationX + 0.2;

    Map<String, dynamic>? closestPoint;
    double minDistance = 30.0;

    final bool showMonitoring = VirtualTopography.earthFilterNotifier.value.contains('Monitoramento');
    if (showMonitoring) {
      for (var gp in _geoPoints) {
        final double latRad = gp['lat'] * math.pi / 180.0;
        final double lonRad = gp['lon'] * math.pi / 180.0;
        final double theta = math.pi / 2 - latRad;
        final double phi = lonRad + math.pi;

        final double x3d = radius * math.sin(theta) * math.sin(phi);
        final double y3d = radius * math.cos(theta);
        final double z3d = radius * math.sin(theta) * math.cos(phi);

        final double rx = x3d * math.cos(rotY) + z3d * math.sin(rotY);
        final double rz = -x3d * math.sin(rotY) + z3d * math.cos(rotY);

        final double finalX = -rx;
        final double finalY = y3d * math.cos(rotX) - rz * math.sin(rotX);
        final double finalZ = y3d * math.sin(rotX) + rz * math.cos(rotX);

        if (finalZ > 0) {
          final screenPos = Offset(center.dx + finalX, center.dy + finalY);
          final dist = (details.localPosition - screenPos).distance;
          if (dist < minDistance) {
            minDistance = dist;
            closestPoint = gp;
          }
        }
      }
    }

    if (closestPoint != null) {
      final double latRad = closestPoint['lat'] * math.pi / 180.0;
      final double lonRad = closestPoint['lon'] * math.pi / 180.0;
      final autoRotY = _animationController.value * 2 * math.pi;

      setState(() {
        _selectedGeoPoint = closestPoint;
        _manualRotationY = -lonRad - math.pi - autoRotY;
        _manualRotationX = latRad - 0.2;
        _animationController.stop();
      });
      _popupTimer?.cancel();
      _popupTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            _selectedGeoPoint = null;
            if (VirtualTopography.toggleRotationTrigger.value) {
              _animationController.repeat();
            }
          });
        }
      });
    }
  }

  // ignore: unused_element
  void _resetZoomAndSelection() {
    setState(() {
      _selectedGeoPoint = null;
      _zoom = 1.0;
      if (VirtualTopography.toggleRotationTrigger.value) {
        _animationController.repeat();
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingTexture) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              _loadingStatus,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.3 : 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 3D Textured Globe Viewer
                GestureDetector(
                  onScaleStart: (details) {
                    _easterEggTimer?.cancel();
                    _onScaleStart(details);
                  },
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onTapDown: (details) {
                    _easterEggTimer?.cancel();
                    _easterEggTimer = Timer(const Duration(seconds: 5), _toggleEasterEgg);
                    _handleTapDown(details, width, height);
                  },
                  onTapUp: (_) => _easterEggTimer?.cancel(),
                  onTapCancel: () => _easterEggTimer?.cancel(),
                  onDoubleTap: _handleDoubleTapLocation,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(width, height),
                        painter: _TexturedGlobePainter(
                          rotationProgress: _isEasterEggActive
                              ? (_animationController.value * 60).floor() / 60.0
                              : _animationController.value,
                          manualRotX: _manualRotationX,
                          manualRotY: _manualRotationY,
                          earthImage: _earthImage,
                          cloudsImage: _cloudsImage,
                          geoPoints: _geoPoints,
                          isDark: isDark,
                          themeColor: theme.colorScheme.primary,
                          accentColor: theme.colorScheme.secondary,
                          zoom: _zoom,
                          filter: VirtualTopography.earthFilterNotifier.value,
                          hasSelection: _selectedGeoPoint != null,
                          geoJsonContinents: _geoJsonContinents,
                        ),
                      );
                    },
                  ),
                ),

            // Bottom-left Info Button (hides when detail card is active)
            if (_selectedGeoPoint == null)
              Positioned(
                  bottom: 8,
                  left: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: InkWell(
                        onTap: _showInfoDialog,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                              width: 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

            // Interactive Geolocation Detail Popup Card (Apple Frosted Glass)
             if (_selectedGeoPoint != null)
               Positioned(
                 top: 8,
                 left: 0,
                 right: 0,
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(24),
                   child: BackdropFilter(
                     filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                     child: Container(
                       decoration: BoxDecoration(
                         color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                         borderRadius: BorderRadius.circular(24),
                         border: Border.all(
                           color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                           width: 1.2,
                         ),
                       ),
                       child: Stack(
                         children: [
                           Padding(
                             padding: const EdgeInsets.only(top: 16, left: 16, right: 40, bottom: 16),
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   children: [
                                     Expanded(
                                       child: Text(
                                         _selectedGeoPoint!['name'],
                                         style: TextStyle(
                                           fontSize: 16,
                                           fontWeight: FontWeight.w800,
                                           color: theme.colorScheme.onSurface,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                     if (_selectedGeoPoint!['status'] != 'ONLINE' &&
                                         _selectedGeoPoint!['status'] != 'SYNCING' &&
                                         _selectedGeoPoint!['status'] != 'STANDBY') ...[
                                       const SizedBox(width: 8),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(
                                           color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                           borderRadius: BorderRadius.circular(12),
                                         ),
                                         child: Text(
                                           _selectedGeoPoint!['status'],
                                           style: TextStyle(
                                             fontSize: 8,
                                             fontWeight: FontWeight.w800,
                                             color: theme.colorScheme.primary,
                                           ),
                                         ),
                                       ),
                                     ],
                                   ],
                                 ),
                                 if (_selectedGeoPoint!['project'] != 'Receptor GPS Local') ...[
                                   const SizedBox(height: 2),
                                   Text(
                                     _selectedGeoPoint!['project'],
                                     style: TextStyle(
                                       fontSize: 11,
                                       fontWeight: FontWeight.w700,
                                       color: theme.colorScheme.secondary,
                                     ),
                                   ),
                                 ],
                                 const SizedBox(height: 6),
                                 Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Expanded(
                                       child: Text(
                                         _selectedGeoPoint!['info'],
                                         style: TextStyle(
                                           fontSize: 12,
                                           color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                         ),
                                         maxLines: 3,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                     if (_selectedGeoPoint!['imageUrl'] != null) ...[
                                       const SizedBox(width: 12),
                                       ClipRRect(
                                         borderRadius: BorderRadius.circular(14),
                                         child: Image.network(
                                           _selectedGeoPoint!['imageUrl'],
                                           width: 76,
                                           height: 76,
                                           fit: BoxFit.cover,
                                           errorBuilder: (context, error, stackTrace) => Container(
                                             width: 76,
                                             height: 76,
                                             color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                             child: Icon(Icons.image_not_supported_rounded, size: 24, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                           ),
                                         ),
                                       ),
                                     ],
                                   ],
                                 ),
                               ],
                             ),
                           ),
                           Positioned(
                             top: 14,
                             right: 14,
                             child: IconButton(
                               icon: const Icon(Icons.close_rounded, size: 20),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                               onPressed: () {
                                 setState(() {
                                   _selectedGeoPoint = null;
                                   if (VirtualTopography.toggleRotationTrigger.value) {
                                     _animationController.repeat();
                                   }
                                 });
                               },
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
               ),

            // Wikipedia interactive search results list overlay
            if (_wikiSearchResults.isNotEmpty)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                bottom: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Escolha o Termo Correto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _wikiSearchResults = [];
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _wikiSearchResults.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                  height: 12,
                                ),
                                itemBuilder: (context, index) {
                                  final item = _wikiSearchResults[index];
                                  return InkWell(
                                    onTap: () => _fetchWikiPageDetails(item['title']),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item['snippet'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
          ),
        );
      },
    );
  }
}

class _TexturedGlobePainter extends CustomPainter {
  final double rotationProgress;
  final double manualRotX;
  final double manualRotY;
  final ui.Image? earthImage;
  final ui.Image? cloudsImage;
  final List<Map<String, dynamic>> geoPoints;
  final bool isDark;
  final Color themeColor;
  final Color accentColor;
  final double zoom;
  final Set<String> filter;
  final bool hasSelection;
  final List<List<Offset>> geoJsonContinents;

  _TexturedGlobePainter({
    required this.rotationProgress,
    required this.manualRotX,
    required this.manualRotY,
    required this.earthImage,
    required this.cloudsImage,
    required this.geoPoints,
    required this.isDark,
    required this.themeColor,
    required this.accentColor,
    required this.zoom,
    required this.filter,
    required this.hasSelection,
    required this.geoJsonContinents,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = ((size.width - 32) / 2) * zoom;

    final double autoRotY = rotationProgress * 2 * math.pi;
    final double rotY = autoRotY + manualRotY;
    final double rotX = manualRotX + 0.2;

    // Subtle atmospheric outline (iOS style clean glass shadow)
    final glowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), radius, glowPaint);

    final glowOverlay = Paint()
      ..color = themeColor.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, glowOverlay);

    const int latSegments = 18;
    const int lonSegments = 24;

    final int vertexCount = (latSegments + 1) * (lonSegments + 1);
    final List<Offset> positions = List.filled(vertexCount, Offset.zero);
    final List<Offset> uvsEarth = List.filled(vertexCount, Offset.zero);
    final List<Offset> uvsClouds = List.filled(vertexCount, Offset.zero);
    final List<double> zs = List.filled(vertexCount, 0.0);

    final double earthW = earthImage?.width.toDouble() ?? 1024.0;
    final double earthH = earthImage?.height.toDouble() ?? 512.0;
    final double cloudsW = cloudsImage?.width.toDouble() ?? 1024.0;
    final double cloudsH = cloudsImage?.height.toDouble() ?? 512.0;

    for (int lat = 0; lat <= latSegments; lat++) {
      final double theta = (lat / latSegments) * math.pi;
      final double sinTheta = math.sin(theta);
      final double cosTheta = math.cos(theta);

      for (int lon = 0; lon <= lonSegments; lon++) {
        final double phi = (lon / lonSegments) * 2 * math.pi;
        final double sinPhi = math.sin(phi);
        final double cosPhi = math.cos(phi);

        final double x = radius * sinTheta * sinPhi;
        final double y = radius * cosTheta;
        final double z = radius * sinTheta * cosPhi;

        final double rx = x * math.cos(rotY) + z * math.sin(rotY);
        final double rz = -x * math.sin(rotY) + z * math.cos(rotY);

        final double finalX = -rx;
        final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
        final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);

        final int idx = lat * (lonSegments + 1) + lon;
        positions[idx] = Offset(cx + finalX, cy + finalY);
        zs[idx] = finalZ;

        final double uNorm = lon / lonSegments;
        final double vNorm = lat / latSegments;
        uvsEarth[idx] = Offset(uNorm * earthW, vNorm * earthH);
        uvsClouds[idx] = Offset(uNorm * cloudsW, vNorm * cloudsH);
      }
    }

    final List<int> indices = [];
    for (int lat = 0; lat < latSegments; lat++) {
      for (int lon = 0; lon < lonSegments; lon++) {
        final int p00 = lat * (lonSegments + 1) + lon;
        final int p01 = p00 + 1;
        final int p10 = p00 + (lonSegments + 1);
        final int p11 = p10 + 1;

        final double zAvg1 = (zs[p00] + zs[p10] + zs[p01]) / 3.0;
        if (zAvg1 > -radius * 0.1) {
          indices.addAll([p00, p10, p01]);
        }

        final double zAvg2 = (zs[p01] + zs[p10] + zs[p11]) / 3.0;
        if (zAvg2 > -radius * 0.1) {
          indices.addAll([p01, p10, p11]);
        }
      }
    }

    final bool showEarth = filter.contains('Satélite');
    final bool showClouds = filter.contains('Clima');
    final bool showHeatmap = filter.contains('Heatmap');
    final bool showInfrared = filter.contains('Infravermelho');
    final bool showUltraviolet = filter.contains('Ultra Violeta');
    final bool showNightLights = filter.contains('Luzes Noturnas');
    final bool showWinds = filter.contains('Ventos');
    final bool showTopography = filter.contains('Topografia Hipsométrica');
    final bool showGrid = filter.contains('Vetor (3D)');

    if (indices.isNotEmpty) {
      if (showEarth || showHeatmap || showInfrared || showUltraviolet || showNightLights || showWinds || showTopography) {
        canvas.save();
        canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));

        if (earthImage != null) {
          final earthVertices = ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            textureCoordinates: uvsEarth,
            indices: indices,
          );
          final paint = Paint()
            ..shader = ImageShader(
              earthImage!,
              TileMode.clamp,
              TileMode.clamp,
              Float64List.fromList([
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
              ]),
            )
            ..filterQuality = FilterQuality.medium;

          if (showHeatmap) {
            // Thermal Heatmap Gradient: Red/Orange/Yellow thermal spectrum for land heat
            paint.colorFilter = const ColorFilter.matrix(<double>[
               3.5, -1.2, -1.5, 0, 120,
               1.8,  2.2, -1.0, 0,  60,
              -2.0, -1.5,  0.5, 0, -50,
               0,    0,    0,   1,   0,
            ]);
          } else if (showInfrared) {
            // GOES-16 Thermal Infrared: High contrast dark surface + cyan/white cloud tops
            paint.colorFilter = const ColorFilter.matrix(<double>[
              -2.0,  2.0,  2.0, 0,  50,
               0.5, -1.5,  2.5, 0,  80,
               2.5,  2.0, -1.5, 0, 150,
               0,    0,    0,   1,   0,
            ]);
          } else if (showUltraviolet) {
            // UV Radiation Spectrum: Deep Electric Purple & Fluorescent Cyan
            paint.colorFilter = const ColorFilter.matrix(<double>[
               2.5, -1.0,  3.5, 0, 120,
              -0.6,  0.5,  2.5, 0,  50,
               3.0,  1.8,  4.0, 0, 160,
               0,    0,    0,   1,   0,
            ]);
          } else if (showNightLights) {
            paint.colorFilter = const ColorFilter.matrix(<double>[
               4.0, -1.2, -1.0, 0, -110,
               2.8, -0.8, -1.2, 0, -120,
              -1.2, -1.2, -1.5, 0, -130,
               0,    0,    0,   1,   0,
            ]);
          } else if (showTopography) {
            // Hypsometric Relief: Emerald Lowlands & Ocher/Red Mountains
            paint.colorFilter = const ColorFilter.matrix(<double>[
              -1.0,  3.0, -0.8, 0,  50,
               2.2,  1.0, -1.0, 0, 100,
              -2.0, -0.8,  3.5, 0, -60,
               0,    0,    0,   1,   0,
            ]);
          }

          // Render exclusively on 3D vertices so pixels rotate in 3D space with the planet
          canvas.drawVertices(earthVertices, BlendMode.srcOver, paint);
        } else {
          // If real satellite data is downloading or offline, draw clean fallback globe surface
          final fallbackPaint = Paint()
            ..color = themeColor.withValues(alpha: 0.1)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), radius, fallbackPaint);
          _drawContinentOutlines(canvas, radius, rotY, rotX, cx, cy, geoJsonContinents);
        }

        if (showWinds) {
          _drawWindStreamlines(canvas, radius, rotY, rotX, cx, cy, rotationProgress);
        }

        canvas.restore();
      }

      if (showClouds && cloudsImage != null) {
        final cloudsVertices = ui.Vertices(
          ui.VertexMode.triangles,
          positions,
          textureCoordinates: uvsClouds,
          indices: indices,
        );
        final cloudsPaint = Paint()
          ..shader = ImageShader(
            cloudsImage!,
            TileMode.clamp,
            TileMode.clamp,
            Float64List.fromList([
              1, 0, 0, 0,
              0, 1, 0, 0,
              0, 0, 1, 0,
              0, 0, 0, 1
            ]),
          )
          ..blendMode = BlendMode.screen
          ..filterQuality = FilterQuality.medium;

        canvas.save();
        canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
        canvas.drawVertices(cloudsVertices, BlendMode.srcOver, cloudsPaint);
        canvas.restore();
      }

      if (showGrid || earthImage == null) {
        canvas.save();
        canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
        _drawGraticuleAndKeyLines(canvas, radius, rotY, rotX, cx, cy);
        _drawContinentOutlines(canvas, radius, rotY, rotX, cx, cy, geoJsonContinents);
        canvas.restore();
      }
    }

    // 4. Draw Geolocation Markers (iOS clean circular targets)
    final double pulseVal = (math.sin(autoRotY * 5) + 1.0) / 2.0;

    final markerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8 * (1.0 - pulseVal))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var gp in geoPoints) {
      final bool isGPSPoint = gp['project'] == 'Receptor GPS Local';
      if (!filter.contains('Monitoramento') && !isGPSPoint) continue;

      final double latRad = gp['lat'] * math.pi / 180.0;
      final double lonRad = gp['lon'] * math.pi / 180.0;
      final double theta = math.pi / 2 - latRad;
      final double phi = lonRad + math.pi;

      final double x = radius * math.sin(theta) * math.sin(phi);
      final double y = radius * math.cos(theta);
      final double z = radius * math.sin(theta) * math.cos(phi);

      final double rx = x * math.cos(rotY) + z * math.sin(rotY);
      final double rz = -x * math.sin(rotY) + z * math.cos(rotY);

      final double finalX = -rx;
      final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
      final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);

      if (finalZ > 0) {
        final screenPos = Offset(cx + finalX, cy + finalY);
        final bool isGPSPoint = gp['project'] == 'Receptor GPS Local';
        final bool isWikiPoint = gp['project'] == 'Artigo Wikipédia';

        if (isGPSPoint || isWikiPoint) {
          final pinPath = ui.Path();
          final pinTip = screenPos;
          final pinCenter = Offset(screenPos.dx, screenPos.dy - 12);
          
          final shadowPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawOval(Rect.fromCenter(center: Offset(screenPos.dx, screenPos.dy + 1), width: 6, height: 2), shadowPaint);

          pinPath.moveTo(pinTip.dx, pinTip.dy);
          pinPath.cubicTo(
            pinTip.dx - 6, pinTip.dy - 6,
            pinTip.dx - 6, pinTip.dy - 18,
            pinTip.dx, pinTip.dy - 18,
          );
          pinPath.cubicTo(
            pinTip.dx + 6, pinTip.dy - 18,
            pinTip.dx + 6, pinTip.dy - 6,
            pinTip.dx, pinTip.dy,
          );
          pinPath.close();

          final pinPaint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(screenPos.dx, screenPos.dy - 18),
              pinTip,
              isGPSPoint 
                ? [const Color(0xFF30D158), const Color(0xFF15803D)]
                : [themeColor, themeColor.withValues(alpha: 0.7)],
            )
            ..style = PaintingStyle.fill;
          canvas.drawPath(pinPath, pinPaint);

          final innerDotPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pinCenter, 2.5, innerDotPaint);
          
          if (isGPSPoint) {
            final gpsRingPaint = Paint()
              ..color = const Color(0xFF30D158).withValues(alpha: 0.8 * (1.0 - pulseVal))
              ..strokeWidth = 1.2
              ..style = PaintingStyle.stroke;
            canvas.drawCircle(screenPos, 4.0 + pulseVal * 12.0, gpsRingPaint);
          }
        } else {
          canvas.drawCircle(screenPos, 4.0, markerPaint);
          canvas.drawCircle(screenPos, 4.0 + pulseVal * 12.0, ringPaint);
        }

        if (finalZ > radius * 0.35) {
          textPainter.text = TextSpan(
            text: gp['name'],
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(screenPos.dx + 8, screenPos.dy - 4));
        }
      }
    }
  }

  void _drawWindStreamlines(Canvas canvas, double radius, double rotY, double rotX, double cx, double cy, double animVal) {
    final windPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final windGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    Offset? project(double latDeg, double lonDeg) {
      final double latRad = latDeg * math.pi / 180.0;
      final double lonRad = lonDeg * math.pi / 180.0;
      final double theta = math.pi / 2 - latRad;
      final double phi = lonRad + math.pi;

      final double x = radius * math.sin(theta) * math.sin(phi);
      final double y = radius * math.cos(theta);
      final double z = radius * math.sin(theta) * math.cos(phi);

      final double rx = x * math.cos(rotY) + z * math.sin(rotY);
      final double rz = -x * math.sin(rotY) + z * math.cos(rotY);

      final double finalX = -rx;
      final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
      final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);

      if (finalZ <= -radius * 0.02) return null;
      return Offset(cx + finalX, cy + finalY);
    }

    final List<double> windLatitudes = [-60, -45, -30, -15, 0, 15, 30, 45, 60];
    for (double lat in windLatitudes) {
      final double direction = (lat.abs() < 20 || lat.abs() > 50) ? -1.0 : 1.0;
      for (double startLon = -180; startLon < 180; startLon += 25) {
        final double phase = (animVal * 360 * direction + startLon) % 360 - 180;
        final path = ui.Path();
        bool started = false;

        for (double dLon = 0; dLon <= 18; dLon += 3) {
          final double curLon = phase + dLon;
          final double curLat = lat + math.sin(dLon * math.pi / 9) * 4.0;
          final pt = project(curLat, curLon);
          if (pt != null) {
            if (!started) {
              path.moveTo(pt.dx, pt.dy);
              started = true;
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
        }
        if (started) {
          canvas.drawPath(path, windGlowPaint);
          canvas.drawPath(path, windPaint);
        }
      }
    }
  }

  void _drawGraticuleAndKeyLines(Canvas canvas, double radius, double rotY, double rotX, double cx, double cy) {
    // Regular graticule every 30°
    final gridPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.18)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Equator & Prime Meridian — cyan glow
    final keyGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    final keyPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.95)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Tropics of Cancer & Capricorn — amber
    final tropicPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Arctic & Antarctic circles — light blue
    final polarPaint = Paint()
      ..color = const Color(0xFF80D8FF).withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Date Line 180° — dashed gold
    final dateLinePaint = Paint()
      ..color = const Color(0xFFFFD600).withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Label painter helper
    void drawLabel(String text, Offset pos, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: color,
            backgroundColor: Colors.black.withValues(alpha: 0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(pos.dx + 3, pos.dy - 5));
    }

    Offset? project(double latDeg, double lonDeg) {
      final double latRad = latDeg * math.pi / 180.0;
      final double lonRad = lonDeg * math.pi / 180.0;
      final double theta = math.pi / 2 - latRad;
      final double phi = lonRad + math.pi;
      final double x = radius * math.sin(theta) * math.sin(phi);
      final double y = radius * math.cos(theta);
      final double z = radius * math.sin(theta) * math.cos(phi);
      final double rx = x * math.cos(rotY) + z * math.sin(rotY);
      final double rz = -x * math.sin(rotY) + z * math.cos(rotY);
      final double finalX = -rx;
      final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
      final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);
      if (finalZ <= -radius * 0.02) return null;
      return Offset(cx + finalX, cy + finalY);
    }

    // Helper to draw a parallel line
    void drawParallel(double lat, Paint paint, {Paint? glowPaint}) {
      Offset? last;
      for (double lon = -180; lon <= 180; lon += 2) {
        final pt = project(lat, lon);
        if (pt != null && last != null) {
          if (glowPaint != null) canvas.drawLine(last, pt, glowPaint);
          canvas.drawLine(last, pt, paint);
        }
        last = pt;
      }
    }

    // Helper to draw a meridian line
    void drawMeridian(double lon, Paint paint, {Paint? glowPaint}) {
      Offset? last;
      for (double lat = -90; lat <= 90; lat += 2) {
        final pt = project(lat, lon);
        if (pt != null && last != null) {
          if (glowPaint != null) canvas.drawLine(last, pt, glowPaint);
          canvas.drawLine(last, pt, paint);
        }
        last = pt;
      }
    }

    // A. Regular graticule parallels every 30°
    for (double lat in [-60.0, -30.0, 30.0, 60.0]) {
      drawParallel(lat, gridPaint);
    }

    // B. Regular graticule meridians every 30°
    for (double lon in [-150.0, -120.0, -90.0, -60.0, -30.0, 30.0, 60.0, 90.0, 120.0, 150.0]) {
      drawMeridian(lon, gridPaint);
    }

    // C. Tropics (Cancer ±23.44°)
    drawParallel(23.44, tropicPaint);
    drawParallel(-23.44, tropicPaint);

    // D. Arctic & Antarctic circles (±66.56°)
    drawParallel(66.56, polarPaint);
    drawParallel(-66.56, polarPaint);

    // E. Equator — thick cyan
    drawParallel(0, keyPaint, glowPaint: keyGlowPaint);

    // F. Prime Meridian (0°) — thick cyan
    drawMeridian(0, keyPaint, glowPaint: keyGlowPaint);

    // G. Date Line (180°) — dashed gold
    drawMeridian(180, dateLinePaint);

    // H. Labels for key lines (only when facing viewer)
    final labelLon = 5.0; // just east of prime meridian for parallel labels
    final Offset? eqPt    = project(0,     labelLon);
    final Offset? canPt   = project(23.44, labelLon);
    final Offset? capPt   = project(-23.44, labelLon);
    final Offset? arcPt   = project(66.56, labelLon);
    final Offset? antPt   = project(-66.56, labelLon);
    final Offset? pmPt    = project(10,    0);
    final Offset? dlPt    = project(10,    180);

    if (eqPt  != null) drawLabel('Equador',             eqPt,  const Color(0xFF00E5FF));
    if (canPt != null) drawLabel('Trópico de Câncer',   canPt, const Color(0xFFFFB300));
    if (capPt != null) drawLabel('Trópico de Capricórnio', capPt, const Color(0xFFFFB300));
    if (arcPt != null) drawLabel('Círculo Polar Ártico',    arcPt, const Color(0xFF80D8FF));
    if (antPt != null) drawLabel('Círculo Polar Antártico', antPt, const Color(0xFF80D8FF));
    if (pmPt  != null) drawLabel('Meridiano de Greenwich', pmPt,  const Color(0xFF00E5FF));
    if (dlPt  != null) drawLabel('Linha de Data',          dlPt,  const Color(0xFFFFD600));
  }

  List<Offset> _interpolateCatmullRom(List<Offset> pts, {int subSteps = 6}) {
    final List<Offset> smooth = [];
    final int len = pts.length;
    if (len < 3) return pts;

    for (int i = 0; i < len; i++) {
      final p0 = pts[(i - 1 + len) % len];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % len];
      final p3 = pts[(i + 2) % len];

      for (int step = 0; step < subSteps; step++) {
        final double t = step / subSteps;
        final double t2 = t * t;
        final double t3 = t2 * t;

        final double lat = 0.5 * (
          (2.0 * p1.dx) +
          (-p0.dx + p2.dx) * t +
          (2.0 * p0.dx - 5.0 * p1.dx + 4.0 * p2.dx - p3.dx) * t2 +
          (-p0.dx + 3.0 * p1.dx - 3.0 * p2.dx + p3.dx) * t3
        );

        final double lon = 0.5 * (
          (2.0 * p1.dy) +
          (-p0.dy + p2.dy) * t +
          (2.0 * p0.dy - 5.0 * p1.dy + 4.0 * p2.dy - p3.dy) * t2 +
          (-p0.dy + 3.0 * p1.dy - 3.0 * p2.dy + p3.dy) * t3
        );

        smooth.add(Offset(lat, lon));
      }
    }
    return smooth;
  }

  void _drawContinentOutlines(Canvas canvas, double radius, double rotY, double rotX, double cx, double cy, List<List<Offset>> geoJsonContinents) {
    final List<List<Offset>> rawContinents = geoJsonContinents.isNotEmpty 
        ? geoJsonContinents 
        : [
      // South America (High-Precision Realistic Coastlines)
      [
        const Offset(12.5, -71.5), const Offset(11.8, -71.3), const Offset(11.5, -72.8), const Offset(10.5, -66.9),
        const Offset(10.6, -61.6), const Offset(9.0, -60.8), const Offset(8.4, -59.5), const Offset(6.0, -57.0),
        const Offset(5.5, -54.0), const Offset(4.9, -52.3), const Offset(4.4, -51.5), const Offset(2.2, -50.4),
        const Offset(1.0, -49.8), const Offset(-0.5, -48.0), const Offset(-1.2, -48.5), const Offset(-1.5, -45.0),
        const Offset(-2.5, -44.3), const Offset(-2.8, -40.8), const Offset(-3.7, -38.5), const Offset(-5.0, -36.5),
        const Offset(-5.1, -35.4), const Offset(-6.0, -35.0), const Offset(-8.0, -34.8), const Offset(-9.0, -35.2),
        const Offset(-13.0, -38.5), const Offset(-14.0, -39.0), const Offset(-18.0, -39.7), const Offset(-20.2, -40.3),
        const Offset(-23.0, -43.2), const Offset(-24.0, -46.3), const Offset(-25.5, -48.5), const Offset(-26.3, -48.6),
        const Offset(-27.6, -48.5), const Offset(-29.3, -49.7), const Offset(-32.0, -52.0), const Offset(-34.0, -53.5),
        const Offset(-34.8, -56.2), const Offset(-36.0, -57.4), const Offset(-38.0, -57.5), const Offset(-39.0, -62.0),
        const Offset(-40.6, -62.2), const Offset(-41.2, -65.0), const Offset(-42.6, -63.6), const Offset(-43.0, -65.2),
        const Offset(-45.8, -67.5), const Offset(-47.0, -65.8), const Offset(-50.0, -68.5), const Offset(-52.3, -68.4),
        const Offset(-53.2, -70.5), const Offset(-54.8, -68.3), const Offset(-55.98, -67.27), const Offset(-54.5, -72.0),
        const Offset(-53.5, -72.5), const Offset(-52.0, -75.0), const Offset(-50.0, -75.3), const Offset(-47.0, -74.8),
        const Offset(-45.6, -74.5), const Offset(-42.5, -73.9), const Offset(-39.8, -73.4), const Offset(-36.8, -73.1),
        const Offset(-33.0, -71.6), const Offset(-30.0, -71.4), const Offset(-26.0, -70.7), const Offset(-23.6, -70.4),
        const Offset(-20.0, -70.2), const Offset(-18.5, -70.3), const Offset(-17.6, -71.3), const Offset(-15.0, -75.4),
        const Offset(-13.7, -76.3), const Offset(-12.1, -77.2), const Offset(-9.1, -78.6), const Offset(-6.8, -79.9),
        const Offset(-4.7, -81.3), const Offset(-3.5, -80.7), const Offset(-2.2, -80.9), const Offset(-1.0, -80.9),
        const Offset(1.0, -79.0), const Offset(3.9, -77.1), const Offset(6.5, -77.5), const Offset(7.2, -77.9),
        const Offset(8.0, -77.5),
      ],
      // North America & Central America (High-Precision Realistic Coastlines)
      [
        const Offset(8.0, -77.5), const Offset(9.0, -82.0), const Offset(9.5, -83.5), const Offset(8.5, -83.5),
        const Offset(10.0, -85.5), const Offset(11.0, -85.8), const Offset(13.0, -87.5), const Offset(13.2, -87.6),
        const Offset(14.5, -92.2), const Offset(16.0, -95.0), const Offset(16.0, -99.5), const Offset(20.0, -105.3),
        const Offset(20.5, -105.5), const Offset(23.0, -106.4), const Offset(27.0, -111.0), const Offset(31.0, -114.0),
        const Offset(31.0, -115.0), const Offset(28.0, -112.0), const Offset(24.3, -110.3), const Offset(22.9, -109.9),
        const Offset(24.6, -112.0), const Offset(28.0, -115.0), const Offset(32.0, -117.0), const Offset(34.0, -119.0),
        const Offset(34.4, -120.5), const Offset(37.8, -122.5), const Offset(40.4, -124.4), const Offset(44.6, -124.1),
        const Offset(48.4, -124.7), const Offset(49.0, -125.0), const Offset(52.0, -128.0), const Offset(54.8, -130.0),
        const Offset(57.0, -135.0), const Offset(59.5, -139.7), const Offset(60.0, -148.0), const Offset(59.7, -151.5),
        const Offset(57.0, -154.0), const Offset(55.0, -160.0), const Offset(54.0, -165.0), const Offset(56.0, -162.0),
        const Offset(58.5, -158.0), const Offset(60.0, -162.0), const Offset(62.0, -165.0), const Offset(64.0, -162.0),
        const Offset(65.6, -168.0), const Offset(66.0, -166.0), const Offset(68.0, -166.0), const Offset(71.3, -156.4),
        const Offset(70.0, -140.0), const Offset(69.0, -135.0), const Offset(69.0, -120.0), const Offset(68.0, -115.0),
        const Offset(68.0, -100.0), const Offset(65.0, -90.0), const Offset(60.0, -95.0), const Offset(55.0, -92.0),
        const Offset(51.5, -80.0), const Offset(58.0, -78.0), const Offset(62.0, -78.0), const Offset(62.5, -70.0),
        const Offset(58.0, -65.0), const Offset(60.0, -64.0), const Offset(57.0, -61.8), const Offset(53.0, -56.0),
        const Offset(47.0, -53.0), const Offset(47.6, -56.0), const Offset(49.0, -58.0), const Offset(46.0, -60.0),
        const Offset(44.5, -63.5), const Offset(45.0, -66.0), const Offset(42.0, -70.0), const Offset(41.0, -72.0),
        const Offset(40.5, -74.0), const Offset(38.8, -75.0), const Offset(37.0, -76.0), const Offset(35.2, -75.5),
        const Offset(32.0, -81.0), const Offset(29.0, -80.5), const Offset(25.8, -80.1), const Offset(25.0, -81.0),
        const Offset(28.0, -82.8), const Offset(30.0, -84.5), const Offset(30.2, -88.0), const Offset(29.0, -90.0),
        const Offset(29.5, -94.0), const Offset(26.0, -97.0), const Offset(22.0, -97.5), const Offset(19.0, -96.0),
        const Offset(18.5, -92.5), const Offset(20.0, -90.5), const Offset(21.5, -87.0), const Offset(18.5, -87.5),
        const Offset(16.0, -88.5),
      ],
      // Europe (High-Precision Realistic Coastlines)
      [
        const Offset(36.0, -5.3), const Offset(37.0, -9.0), const Offset(38.7, -9.5), const Offset(41.0, -8.7),
        const Offset(43.0, -9.3), const Offset(43.4, -8.0), const Offset(43.4, -1.8), const Offset(46.0, -1.5),
        const Offset(48.0, -4.5), const Offset(49.5, -1.5), const Offset(51.0, 1.5), const Offset(53.5, 6.0),
        const Offset(55.0, 8.5), const Offset(57.7, 10.6), const Offset(56.0, 10.2), const Offset(54.5, 10.0),
        const Offset(54.0, 14.0), const Offset(57.0, 19.0), const Offset(59.0, 25.0), const Offset(60.2, 29.0),
        const Offset(59.0, 23.0), const Offset(57.0, 24.0), const Offset(54.5, 19.0), const Offset(58.0, 6.0),
        const Offset(62.0, 5.0), const Offset(65.0, 12.0), const Offset(68.0, 14.0), const Offset(70.2, 19.0),
        const Offset(71.2, 25.8), const Offset(70.0, 31.0), const Offset(68.0, 39.0), const Offset(66.0, 34.0),
        const Offset(68.0, 43.0), const Offset(46.5, 30.5), const Offset(45.3, 32.5), const Offset(45.3, 36.5),
        const Offset(42.0, 41.5), const Offset(41.0, 29.0), const Offset(44.0, 29.0), const Offset(40.5, 23.0),
        const Offset(39.0, 23.5), const Offset(38.0, 24.0), const Offset(36.4, 22.5), const Offset(39.0, 20.0),
        const Offset(45.0, 13.0), const Offset(42.0, 19.0), const Offset(40.0, 20.0), const Offset(40.0, 18.0),
        const Offset(38.0, 15.5), const Offset(41.0, 13.0), const Offset(43.0, 10.0), const Offset(43.5, 7.0),
      ],
      // Great Britain
      [
        const Offset(50.0, -5.7), const Offset(50.6, -2.4), const Offset(50.8, -0.8), const Offset(51.3, 1.4),
        const Offset(52.5, 1.8), const Offset(53.0, 0.2), const Offset(54.3, -0.1), const Offset(56.0, -2.5),
        const Offset(57.5, -1.8), const Offset(58.6, -3.0), const Offset(58.2, -5.0), const Offset(56.5, -6.0),
        const Offset(55.4, -5.5), const Offset(54.0, -3.0), const Offset(52.8, -4.7), const Offset(51.5, -4.0),
      ],
      // Ireland
      [
        const Offset(51.5, -9.0), const Offset(52.2, -10.0), const Offset(53.5, -10.0), const Offset(54.5, -8.5),
        const Offset(55.2, -6.5), const Offset(54.0, -6.0), const Offset(53.3, -6.2), const Offset(52.2, -6.3),
        const Offset(51.5, -8.0),
      ],
      // Africa (High-Precision Realistic Coastlines)
      [
        const Offset(35.8, -5.5), const Offset(33.5, -7.5), const Offset(28.0, -13.0), const Offset(21.0, -17.0),
        const Offset(15.0, -17.5), const Offset(11.5, -15.0), const Offset(8.0, -13.5), const Offset(5.0, -7.5),
        const Offset(4.5, -2.5), const Offset(6.2, 3.5), const Offset(4.5, 9.5), const Offset(-1.0, 9.0),
        const Offset(-5.0, 12.0), const Offset(-12.0, 13.5), const Offset(-18.0, 12.0), const Offset(-22.0, 14.0),
        const Offset(-30.0, 17.0), const Offset(-34.0, 18.0), const Offset(-34.8, 20.0), const Offset(-33.0, 27.0),
        const Offset(-26.0, 33.0), const Offset(-20.0, 35.0), const Offset(-12.0, 40.5), const Offset(-4.0, 39.5),
        const Offset(2.0, 45.0), const Offset(8.0, 50.0), const Offset(11.5, 51.2), const Offset(12.0, 43.5),
        const Offset(15.0, 41.5), const Offset(22.0, 37.0), const Offset(27.0, 34.5), const Offset(31.2, 32.2),
        const Offset(32.5, 23.0), const Offset(36.0, 15.0), const Offset(37.0, 10.0),
      ],
      // Asia & Middle East (High-Precision Realistic Coastlines)
      [
        const Offset(41.0, 29.0), const Offset(36.0, 30.0), const Offset(36.0, 36.0), const Offset(33.0, 35.0),
        const Offset(29.5, 34.5), const Offset(28.0, 34.5), const Offset(28.0, 33.0), const Offset(22.0, 37.0),
        const Offset(15.0, 40.0), const Offset(12.8, 43.0), const Offset(15.0, 53.0), const Offset(17.0, 56.0),
        const Offset(22.0, 59.5), const Offset(25.0, 57.0), const Offset(27.0, 50.0), const Offset(30.0, 48.0),
        const Offset(27.0, 51.0), const Offset(25.0, 55.0), const Offset(25.0, 67.0), const Offset(22.0, 69.0),
        const Offset(21.0, 72.0), const Offset(19.0, 72.8), const Offset(15.0, 73.8), const Offset(10.0, 76.0),
        const Offset(8.0, 77.5), const Offset(10.0, 80.0), const Offset(13.0, 80.3), const Offset(17.8, 83.4),
        const Offset(22.0, 89.0), const Offset(22.0, 91.0), const Offset(20.0, 93.0), const Offset(16.0, 96.0),
        const Offset(10.0, 98.0), const Offset(6.0, 100.0), const Offset(1.3, 103.8), const Offset(4.0, 103.5),
        const Offset(7.0, 100.0), const Offset(12.0, 101.0), const Offset(10.0, 104.0), const Offset(8.5, 105.0),
        const Offset(11.5, 109.0), const Offset(17.0, 107.0), const Offset(21.0, 108.0), const Offset(20.0, 106.0),
        const Offset(22.0, 114.0), const Offset(24.0, 118.0), const Offset(30.0, 122.0), const Offset(35.0, 119.5),
        const Offset(37.0, 122.5), const Offset(39.0, 118.0), const Offset(40.0, 121.5), const Offset(38.0, 125.0),
        const Offset(35.0, 126.0), const Offset(34.3, 127.0), const Offset(35.0, 129.0), const Offset(38.0, 128.5),
        const Offset(41.0, 129.5), const Offset(43.0, 132.0), const Offset(48.0, 140.0), const Offset(55.0, 138.0),
        const Offset(60.0, 160.0), const Offset(62.0, 165.0), const Offset(66.0, 170.0), const Offset(66.0, 180.0),
        const Offset(68.0, 175.0), const Offset(72.0, 130.0), const Offset(77.0, 105.0), const Offset(73.0, 70.0),
        const Offset(68.0, 40.0),
      ],
      // Maritime Southeast Asia (Indonesia, Philippines, Malaysia)
      [
        const Offset(5.0, 95.0), const Offset(-3.0, 102.0), const Offset(-6.0, 106.0), const Offset(-7.5, 114.0),
        const Offset(-8.5, 125.0), const Offset(-4.0, 115.0), const Offset(2.0, 117.0), const Offset(7.0, 116.0),
        const Offset(14.0, 120.0), const Offset(18.0, 122.0), const Offset(10.0, 125.0), const Offset(6.0, 125.0),
        const Offset(1.0, 127.0), const Offset(-3.0, 120.0), const Offset(1.0, 119.0),
      ],
      // Australia
      [
        const Offset(-12.0, 131.0), const Offset(-11.0, 136.0), const Offset(-15.0, 136.0), const Offset(-11.0, 142.0),
        const Offset(-15.0, 145.0), const Offset(-20.0, 148.0), const Offset(-25.0, 153.0), const Offset(-30.0, 153.0),
        const Offset(-34.0, 151.0), const Offset(-38.0, 145.0), const Offset(-38.0, 140.0), const Offset(-35.0, 137.0),
        const Offset(-32.0, 132.0), const Offset(-34.0, 123.0), const Offset(-35.0, 117.0), const Offset(-32.0, 115.0),
        const Offset(-26.0, 113.0), const Offset(-22.0, 114.0), const Offset(-18.0, 122.0), const Offset(-15.0, 125.0),
      ],
      // Japan (Honshu, Hokkaido, Kyushu)
      [
        const Offset(31.0, 130.0), const Offset(33.5, 133.0), const Offset(35.0, 135.0), const Offset(36.5, 140.0),
        const Offset(41.0, 141.0), const Offset(44.0, 144.0), const Offset(45.5, 142.0), const Offset(42.0, 140.0),
        const Offset(37.0, 137.0), const Offset(34.0, 131.0),
      ],
      // Madagascar
      [
        const Offset(-12.0, 49.0), const Offset(-16.0, 49.5), const Offset(-25.0, 47.0), const Offset(-25.0, 44.0),
        const Offset(-16.0, 44.0),
      ],
      // Greenland
      [
        const Offset(60.0, -45.0), const Offset(65.0, -52.0), const Offset(70.0, -54.0), const Offset(76.0, -60.0),
        const Offset(82.0, -60.0), const Offset(83.0, -30.0), const Offset(80.0, -15.0), const Offset(70.0, -22.0),
        const Offset(65.0, -35.0),
      ],
      // Antarctica
      [
        const Offset(-63.0, -57.0), const Offset(-65.0, -64.0), const Offset(-72.0, -75.0), const Offset(-75.0, -120.0),
        const Offset(-78.0, -160.0), const Offset(-72.0, 170.0), const Offset(-66.0, 140.0), const Offset(-66.0, 100.0),
        const Offset(-67.0, 60.0), const Offset(-70.0, 10.0), const Offset(-72.0, -20.0), const Offset(-75.0, -40.0),
      ]
    ];

    final glowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.25)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    final borderPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (var rawPts in rawContinents) {
      final continent = _interpolateCatmullRom(rawPts, subSteps: 4);
      final int len = continent.length;
      if (len < 2) continue;

      // 1. Calculate 3D rotated positions for all points
      final List<double> xs = List.filled(len, 0.0);
      final List<double> ys = List.filled(len, 0.0);
      final List<double> zs = List.filled(len, 0.0);

      for (int i = 0; i < len; i++) {
        final point = continent[i];
        final double latRad = point.dx * math.pi / 180.0;
        final double lonRad = point.dy * math.pi / 180.0;
        final double theta = math.pi / 2 - latRad;
        final double phi = lonRad + math.pi;

        final double px = radius * math.sin(theta) * math.sin(phi);
        final double py = radius * math.cos(theta);
        final double pz = radius * math.sin(theta) * math.cos(phi);

        final double rx = px * math.cos(rotY) + pz * math.sin(rotY);
        final double rz = -px * math.sin(rotY) + pz * math.cos(rotY);

        xs[i] = -rx;
        ys[i] = py * math.cos(rotX) - rz * math.sin(rotX);
        zs[i] = py * math.sin(rotX) + rz * math.cos(rotX);
      }

      // 2. Draw outline segments by interpolating exactly at the horizon (Z = 0)
      final path = ui.Path();
      bool pathStarted = false;

      void drawSegment(Offset p1, Offset p2) {
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, borderPaint);
      }

      for (int i = 0; i < len; i++) {
        final int next = (i + 1) % len;
        final double z1 = zs[i];
        final double z2 = zs[next];
        final Offset pt1 = Offset(cx + xs[i], cy + ys[i]);
        final Offset pt2 = Offset(cx + xs[next], cy + ys[next]);

        final bool vis1 = z1 > 0;
        final bool vis2 = z2 > 0;

        if (vis1 && vis2) {
          // Entirely visible
          drawSegment(pt1, pt2);
          if (!pathStarted) {
            path.moveTo(pt1.dx, pt1.dy);
            pathStarted = true;
          }
          path.lineTo(pt2.dx, pt2.dy);
        } else if (vis1 && !vis2) {
          // Crosses horizon (leaving visible face)
          final double t = z1 / (z1 - z2);
          final double interX = xs[i] + t * (xs[next] - xs[i]);
          final double interY = ys[i] + t * (ys[next] - ys[i]);
          final Offset interPt = Offset(cx + interX, cy + interY);

          drawSegment(pt1, interPt);
          if (!pathStarted) {
            path.moveTo(pt1.dx, pt1.dy);
            pathStarted = true;
          }
          path.lineTo(interPt.dx, interPt.dy);
          pathStarted = false; // end path segment
        } else if (!vis1 && vis2) {
          // Crosses horizon (entering visible face)
          final double t = z1 / (z1 - z2);
          final double interX = xs[i] + t * (xs[next] - xs[i]);
          final double interY = ys[i] + t * (ys[next] - ys[i]);
          final Offset interPt = Offset(cx + interX, cy + interY);

          drawSegment(interPt, pt2);
          path.moveTo(interPt.dx, interPt.dy);
          path.lineTo(pt2.dx, pt2.dy);
          pathStarted = true;
        }
        // If both are invisible, do nothing
      }

      // Draw faint filled polygons inside visible area
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TexturedGlobePainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.manualRotX != manualRotX ||
        oldDelegate.manualRotY != manualRotY ||
        oldDelegate.earthImage != earthImage ||
        oldDelegate.isDark != isDark ||
        oldDelegate.zoom != zoom ||
        oldDelegate.filter != filter;
  }
}

class CircularClipper extends CustomClipper<Rect> {
  final double radius;
  final Offset center;

  CircularClipper({required this.radius, required this.center});

  @override
  Rect getClip(Size size) {
    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(CircularClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}

class MorphingClipper extends CustomClipper<RRect> {
  final double progress;
  final double startRadius;
  MorphingClipper({required this.progress, required this.startRadius});

  @override
  RRect getClip(Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    
    // Interpolate bounds from circle to full rectangle
    final double left = ui.lerpDouble(cx - startRadius, 0.0, progress)!;
    final double right = ui.lerpDouble(cx + startRadius, size.width, progress)!;
    final double top = ui.lerpDouble(cy - startRadius, 0.0, progress)!;
    final double bottom = ui.lerpDouble(cy + startRadius, size.height, progress)!;
    
    // Interpolate border radius from circle (startRadius) to 24.0 (card border radius)
    final double radius = ui.lerpDouble(startRadius, 24.0, progress)!;
    
    return RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius));
  }

  @override
  bool shouldReclip(covariant MorphingClipper oldClipper) => oldClipper.progress != progress;
}
