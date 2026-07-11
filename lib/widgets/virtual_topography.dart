import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VirtualTopography extends StatefulWidget {
  const VirtualTopography({super.key});

  // Global map search query notifier to center the globe on matching locations
  static final ValueNotifier<String> mapSearchQueryNotifier = ValueNotifier('');
  static final ValueNotifier<String> earthFilterNotifier = ValueNotifier('Todos');
  static final ValueNotifier<String?> directSearchTrigger = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> toggleRotationTrigger = ValueNotifier<bool>(true);

  @override
  State<VirtualTopography> createState() => _VirtualTopographyState();
}

class _VirtualTopographyState extends State<VirtualTopography> with SingleTickerProviderStateMixin {
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

  // Flat satellite map transition variables
  bool _showFlatMap = false;
  double _flatMapCenterLat = -23.5505;
  double _flatMapCenterLon = -46.6333;


  ui.Image? _earthImage;
  ui.Image? _cloudsImage;
  bool _isLoadingTexture = true;
  String _loadingStatus = 'CONECTANDO AO SISTEMA DE SATÉLITES...';

  Map<String, dynamic>? _selectedGeoPoint;
  Timer? _popupTimer;
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _wikiSearchResults = [];
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
      duration: const Duration(seconds: 86400), // 24h = real Earth rotation
    )..repeat();

    _downloadEarthTexture();
    VirtualTopography.mapSearchQueryNotifier.addListener(_onMapSearchQueryChanged);
    VirtualTopography.earthFilterNotifier.addListener(_onFilterChanged);
    VirtualTopography.directSearchTrigger.addListener(_onDirectSearchTriggered);
    VirtualTopography.toggleRotationTrigger.addListener(_onToggleRotationChanged);
  }

  @override
  void dispose() {
    VirtualTopography.mapSearchQueryNotifier.removeListener(_onMapSearchQueryChanged);
    VirtualTopography.earthFilterNotifier.removeListener(_onFilterChanged);
    VirtualTopography.directSearchTrigger.removeListener(_onDirectSearchTriggered);
    VirtualTopography.toggleRotationTrigger.removeListener(_onToggleRotationChanged);
    _animationController.dispose();
    _popupTimer?.cancel();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {});
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
  }

  Future<void> _performDirectSearch(String query) async {
    setState(() {
      _isSearchingWiki = true;
      _wikiSearchResults = [];
    });

    final String searchUrl = 'https://pt.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchList = data['query']?['search'] as List?;
        if (searchList != null && searchList.isNotEmpty) {
          final firstItem = searchList.first;
          final String title = firstItem['title'];
          await _fetchWikiPageDetails(title);
        } else {
          _showSnackBar('Nenhum local ou marco encontrado para "$query"');
        }
      }
    } catch (e) {
      debugPrint('Erro na busca direta no satélite: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingWiki = false;
        });
      }
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
            _manualRotationX = -latRad - 0.2;
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      width: 1.2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sobre o Globo 3D',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        const Text(
                          'COMO FUNCIONA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Este globo utiliza fórmulas de projeção esférica tridimensional (matemática 3D) renderizadas em tempo real a 60 FPS. Você pode arrastar para girar e usar o gesto de pinça (pinch) para dar zoom.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'ORIGEM DAS TEXTURAS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A imagem orbital da Terra é obtida de imagens de satélite reais de alta resolução (equiretangulares), atualizadas via repositórios da NASA/Three.js.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'PROJETOS & DADOS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Os marcadores indicam pontos ativos com dados de telemetria meteorológica e fotográfica atuais (como os satélites GOES-16, Landsat-9 e Himawari-9). A barra inferior de busca no mapa permite voar até estas cidades.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.85),
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

  Future<void> _downloadEarthTexture() async {
    try {
      setState(() {
        _loadingStatus = 'CONECTANDO AOS SATÉLITES...';
      });

      final earthUrls = [
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_atmos_2048.jpg',
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg',
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/land_ocean_ice_cloud_2048.jpg',
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/land_ocean_ice_cloud_2048.jpg',
      ];

      final cloudsUrls = [
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_clouds_1024.png',
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_clouds_1024.png',
        'https://raw.githubusercontent.com/mrdoob/three.js/master/examples/textures/planets/earth_clouds_2048.png',
      ];

      final earthImg = await _downloadImage(earthUrls);
      
      if (mounted) {
        setState(() {
          _loadingStatus = 'MAPEANDO CAMADA DE NUVENS...';
        });
      }

      final cloudsImg = await _downloadImage(cloudsUrls);

      if (mounted) {
        setState(() {
          _earthImage = earthImg;
          _cloudsImage = cloudsImg;
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
    _centerOnCoords(lat, lon);

    // Fetch fresh position in the background
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _centerOnCoords(position.latitude, position.longitude);
    } catch (_) {}
  }

  Future<void> _centerOnCoords(double lat, double lon) async {
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
        _manualRotationX = -latRad - 0.2;
        _zoom = 1.1;
        _selectedGeoPoint = userPoint;
        _animationController.stop();
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
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dx = details.localFocalPoint.dx - _dragStartX;
    final dy = details.localFocalPoint.dy - _dragStartY;
    setState(() {
      _manualRotationY = _baseRotationY + dx * 0.006;
      _manualRotationX = (_baseRotationX - dy * 0.006).clamp(-math.pi / 2.2, math.pi / 2.2);
      if (details.scale != 1.0) {
        _zoom = (_baseZoom * details.scale).clamp(0.6, 20.0);
      }
    });
  }

  void _handleTapDown(TapDownDetails details, double width, double height) {
    if (_showFlatMap) return;
    // Shift the tap detection center Y down matching the painter's shift to avoid details card overlapping
    final center = Offset(width / 2, height / 2 + (_selectedGeoPoint != null ? 40.0 : 0.0));
    final radius = (math.min(width, height) * 0.35) * _zoom;

    final autoRotY = _animationController.value * 2 * math.pi;
    final rotY = autoRotY + _manualRotationY;
    final rotX = _manualRotationX + 0.2;

    Map<String, dynamic>? closestPoint;
    double minDistance = 30.0;

    for (var gp in _geoPoints) {
      final double latRad = gp['lat'] * math.pi / 180.0;
      final double lonRad = gp['lon'] * math.pi / 180.0;
      final double theta = math.pi / 2 - latRad;
      final double phi = lonRad + math.pi;

      final double x3d = radius * math.sin(theta) * math.sin(phi);
      final double y3d = -radius * math.cos(theta);
      final double z3d = radius * math.sin(theta) * math.cos(phi);

      final double rx = x3d * math.cos(rotY) + z3d * math.sin(rotY);
      final double rz = -x3d * math.sin(rotY) + z3d * math.cos(rotY);

      final double finalX = rx;
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

    if (closestPoint != null) {
      final double latRad = closestPoint['lat'] * math.pi / 180.0;
      final double lonRad = closestPoint['lon'] * math.pi / 180.0;
      final autoRotY = _animationController.value * 2 * math.pi;

      setState(() {
        _selectedGeoPoint = closestPoint;
        _manualRotationY = -lonRad - math.pi - autoRotY;
        _manualRotationX = -latRad - 0.2;
        _zoom = 1.1; // Reduced zoom from 1.35 to 1.1 to avoid overlapping the details card
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
    } else {
      setState(() {
        _selectedGeoPoint = null;
        if (VirtualTopography.toggleRotationTrigger.value) {
          _animationController.repeat();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.3 : 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 3D Textured Globe Viewer
                GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onTapDown: (details) => _handleTapDown(details, width, height),
                  onDoubleTap: _handleDoubleTapLocation,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(width, height),
                        painter: _TexturedGlobePainter(
                          rotationProgress: _animationController.value,
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
                            color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.12),
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
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
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
                                      ],
                                     ),
                                     const SizedBox(height: 1),
                                     Text(
                                      _selectedGeoPoint!['project'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedGeoPoint!['info'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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
                                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                    ),
                                  ),
                              ],
                            ],
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
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
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
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
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
                                              color: theme.colorScheme.onSurface.withOpacity(0.55),
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
  final String filter;
  final bool hasSelection;

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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    // Shift globe center Y down by 40dp when selected to avoid overlapping the top details card
    final double cy = size.height / 2 + (hasSelection ? 40.0 : 0.0);
    final double radius = (math.min(size.width, size.height) * 0.35) * zoom;

    final double autoRotY = rotationProgress * 2 * math.pi;
    final double rotY = autoRotY + manualRotY;
    final double rotX = manualRotX + 0.2;

    // Subtle atmospheric outline (iOS style clean glass shadow)
    final glowPaint = Paint()
      ..color = themeColor.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), radius, glowPaint);

    final glowOverlay = Paint()
      ..color = themeColor.withOpacity(0.02)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, glowOverlay);

    const int latSegments = 18;
    const int lonSegments = 24;

    final int vertexCount = (latSegments + 1) * (lonSegments + 1);
    final List<Offset> positions = List.filled(vertexCount, Offset.zero);
    final List<Offset> uvs = List.filled(vertexCount, Offset.zero);
    final List<double> zs = List.filled(vertexCount, 0.0);

    final double imgW = earthImage?.width.toDouble() ?? 1024.0;
    final double imgH = earthImage?.height.toDouble() ?? 512.0;

    for (int lat = 0; lat <= latSegments; lat++) {
      final double theta = (lat / latSegments) * math.pi;
      final double sinTheta = math.sin(theta);
      final double cosTheta = math.cos(theta);

      for (int lon = 0; lon <= lonSegments; lon++) {
        final double phi = (lon / lonSegments) * 2 * math.pi;
        final double sinPhi = math.sin(phi);
        final double cosPhi = math.cos(phi);

        final double x = radius * sinTheta * sinPhi;
        final double y = -radius * cosTheta;
        final double z = radius * sinTheta * cosPhi;

        final double rx = x * math.cos(rotY) + z * math.sin(rotY);
        final double rz = -x * math.sin(rotY) + z * math.cos(rotY);

        final double finalX = rx;
        final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
        final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);

        final int idx = lat * (lonSegments + 1) + lon;
        positions[idx] = Offset(cx + finalX, cy + finalY);
        zs[idx] = finalZ;

        final double u = (lon / lonSegments) * imgW;
        final double v = (lat / latSegments) * imgH;
        uvs[idx] = Offset(u, v);
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

    final bool showEarth = filter != 'Vetor (3D)';
    final bool showClouds = filter == 'Clima' || filter == 'Todos' || filter == 'Wikipédia';
    final bool showGrid = filter == 'Vetor (3D)' || filter == 'Todos';

    if (indices.isNotEmpty) {
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: uvs,
        indices: indices,
      );

      if (showEarth) {
        if (earthImage != null) {
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

          canvas.save();
          canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
          canvas.drawVertices(vertices, BlendMode.srcOver, paint);
          canvas.restore();
        } else {
          final fallbackPaint = Paint()
            ..color = themeColor.withOpacity(0.08)
            ..style = PaintingStyle.fill;
          canvas.save();
          canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
          canvas.drawCircle(Offset(cx, cy), radius, fallbackPaint);
          canvas.restore();
        }
      }

      if (showClouds && cloudsImage != null) {
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
          ..filterQuality = FilterQuality.medium;

        canvas.save();
        canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
        canvas.drawVertices(vertices, BlendMode.srcOver, cloudsPaint);
        canvas.restore();
      }

      if (showGrid || earthImage == null) {
        final gridPaint = Paint()
          ..color = themeColor.withOpacity(earthImage == null ? 0.15 : 0.35)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;

        canvas.save();
        canvas.clipPath(ui.Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius)));
        for (int lat = 0; lat < latSegments; lat++) {
          for (int lon = 0; lon < lonSegments; lon++) {
            final int p00 = lat * (lonSegments + 1) + lon;
            final int p01 = p00 + 1;
            final int p10 = p00 + (lonSegments + 1);

            if (zs[p00] > 0 && zs[p01] > 0) {
              canvas.drawLine(positions[p00], positions[p01], gridPaint);
            }
            if (zs[p00] > 0 && zs[p10] > 0) {
              canvas.drawLine(positions[p00], positions[p10], gridPaint);
            }
          }
        }
        canvas.restore();
      }
    }

    // 4. Draw Geolocation Markers (iOS clean circular targets)
    final double pulseVal = (math.sin(autoRotY * 5) + 1.0) / 2.0;

    final markerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = accentColor.withOpacity(0.8 * (1.0 - pulseVal))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var gp in geoPoints) {
      final isWikiPoint = gp['status'] == 'LUGAR' || gp['status'] == 'PAÍS';
      final isGPSPoint = gp['name'] == 'Minha Localização';

      if (filter == 'Wikipédia' && !isWikiPoint) continue;
      if (filter == 'Clima' && (isWikiPoint || isGPSPoint)) continue;

      final double latRad = gp['lat'] * math.pi / 180.0;
      final double lonRad = gp['lon'] * math.pi / 180.0;
      final double theta = math.pi / 2 - latRad;
      final double phi = lonRad + math.pi;

      final double x = radius * math.sin(theta) * math.sin(phi);
      final double y = -radius * math.cos(theta);
      final double z = radius * math.sin(theta) * math.cos(phi);

      final double rx = x * math.cos(rotY) + z * math.sin(rotY);
      final double rz = -x * math.sin(rotY) + z * math.cos(rotY);

      final double finalX = rx;
      final double finalY = y * math.cos(rotX) - rz * math.sin(rotX);
      final double finalZ = y * math.sin(rotX) + rz * math.cos(rotX);

      if (finalZ > 0) {
        final screenPos = Offset(cx + finalX, cy + finalY);

        if (isGPSPoint || isWikiPoint) {
          final pinPath = ui.Path();
          final pinTip = screenPos;
          final pinCenter = Offset(screenPos.dx, screenPos.dy - 12);
          
          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.35)
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
                ? [const Color(0xFFFF3B30), const Color(0xFFC70039)]
                : [themeColor, themeColor.withOpacity(0.7)],
            )
            ..style = PaintingStyle.fill;
          canvas.drawPath(pinPath, pinPaint);

          final innerDotPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pinCenter, 2.5, innerDotPaint);
          
          if (isGPSPoint) {
            canvas.drawCircle(screenPos, 4.0 + pulseVal * 12.0, ringPaint);
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
              backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.65),
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(screenPos.dx + 8, screenPos.dy - 4));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TexturedGlobePainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.manualRotX != manualRotX ||
        oldDelegate.manualRotY != manualRotY ||
        oldDelegate.earthImage != earthImage ||
        oldDelegate.isDark != isDark ||
        oldDelegate.zoom != zoom;
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
