import 'package:flutter/foundation.dart';

class GlobeController {
  static final GlobeController instance = GlobeController._internal();
  GlobeController._internal();

  final ValueNotifier<String> mapSearchQuery = ValueNotifier('');
  final ValueNotifier<Set<String>> earthFilter = ValueNotifier({'Satélite', 'Clima', 'Vetor (3D)', 'Monitoramento'});
  final ValueNotifier<String?> directSearchTrigger = ValueNotifier<String?>(null);
  final ValueNotifier<bool> toggleRotationTrigger = ValueNotifier<bool>(true);
  final ValueNotifier<bool> closeOverlaysTrigger = ValueNotifier<bool>(false);
  final ValueNotifier<bool> refreshSatelliteTrigger = ValueNotifier<bool>(false);

  VoidCallback? onTapCallback;

  void dispose() {
    mapSearchQuery.dispose();
    earthFilter.dispose();
    directSearchTrigger.dispose();
    toggleRotationTrigger.dispose();
    closeOverlaysTrigger.dispose();
    refreshSatelliteTrigger.dispose();
  }
}

