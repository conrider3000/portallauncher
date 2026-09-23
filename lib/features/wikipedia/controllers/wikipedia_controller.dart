import 'package:flutter/foundation.dart';
import '../services/wikipedia_service.dart';
import '../../../widgets/virtual_topography.dart';

class WikipediaController extends ChangeNotifier {
  // 0: Search Options, 1: Wikipedia Candidates, 2: Full Article
  int _overlayMode = 0;
  int get overlayMode => _overlayMode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, String>> _wikiTermsList = [];
  List<Map<String, String>> get wikiTermsList => _wikiTermsList;

  Map<String, String>? _selectedWikiArticle;
  Map<String, String>? get selectedWikiArticle => _selectedWikiArticle;

  void setMode(int mode) {
    _overlayMode = mode;
    notifyListeners();
  }

  Future<void> fetchCandidateTerms(String query) async {
    _overlayMode = 1;
    _isLoading = true;
    _wikiTermsList = [];
    notifyListeners();

    final terms = await WikipediaService.fetchWikiCandidateTerms(query);
    
    _wikiTermsList = terms;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchArticleFull(String title) async {
    _overlayMode = 2;
    _isLoading = true;
    _selectedWikiArticle = null;
    notifyListeners();

    final article = await WikipediaService.fetchWikiArticleFull(title);
    
    _selectedWikiArticle = article;
    _isLoading = false;
    notifyListeners();

    if (article != null) {
       // Focus 3D Globe camera on term
       VirtualTopography.directSearchTrigger.value = title;
    }
  }

  void reset() {
    _overlayMode = 0;
    _isLoading = false;
    _wikiTermsList = [];
    _selectedWikiArticle = null;
    notifyListeners();
  }
}
