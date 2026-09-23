import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaService {
  static Future<List<Map<String, String>>> fetchWikiCandidateTerms(String query) async {
    final String searchUrl =
        'https://pt.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json&origin=*';
    
    try {
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchList = data['query']?['search'] as List?;
        if (searchList != null && searchList.isNotEmpty) {
          final List<Map<String, String>> terms = [];
          for (var item in searchList) {
            final title = item['title'] as String? ?? '';
            final snippet = (item['snippet'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
            final timestamp = item['timestamp'] as String? ?? '';
            terms.add({
              'title': title,
              'snippet': snippet,
              'timestamp': _formatWikiDate(timestamp),
            });
          }
          return terms;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, String>?> fetchWikiArticleFull(String title) async {
    final String url =
        'https://pt.wikipedia.org/w/api.php?action=query&prop=extracts|revisions&rvprop=timestamp&explaintext&titles=${Uri.encodeComponent(title)}&format=json&origin=*';
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map?;
        if (pages != null && pages.isNotEmpty) {
          final pageId = pages.keys.first;
          final pageData = pages[pageId];
          final String extract = pageData['extract'] ?? 'Conteúdo indisponível.';
          final revisions = pageData['revisions'] as List?;
          String dateStr = 'Atualização recente';
          if (revisions != null && revisions.isNotEmpty) {
            final ts = revisions[0]['timestamp'] as String? ?? '';
            dateStr = _formatWikiDate(ts);
          }
          return {
            'title': title,
            'extract': extract,
            'updated': dateStr,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static String _formatWikiDate(String isoString) {
    if (isoString.isEmpty) return 'Recente';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
