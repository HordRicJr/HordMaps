import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // Focus automatique sur le champ de recherche
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadSearchHistory() {
    // Simuler un historique de recherche basé sur Lomé
    _searchHistory = [
      'Grand Marché de Lomé',
      'Monument de l\'Indépendance',
      'Plage de Lomé',
      'CHU Campus',
      'Restaurant près de moi',
      'Station-service',
      'Pharmacie Lomé',
      'Hôtel Sarakawa',
    ];
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    // Ajouter à l'historique
    if (!_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
      });
    }

    // Effectuer la recherche
    await searchProvider.searchPlaces(query);

    // Revenir à l'écran précédent avec les résultats
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _selectHistoryItem(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher des lieux...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),
        actions: [
          Consumer<SearchProvider>(
            builder: (context, searchProvider, child) {
              return searchProvider.isSearching
                  ? Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(12),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    )
                  : const SizedBox(width: 16);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchController.text.isEmpty) ...[
            // Suggestions rapides
            _buildQuickSuggestions(isDark).animate().slideY(),

            // Historique de recherche
            Expanded(child: _buildSearchHistory(isDark).animate().fadeIn()),
          ] else ...[
            // Suggestions de recherche en temps réel
            Expanded(child: _buildSearchSuggestions(isDark).animate().fadeIn()),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(bool isDark) {
    final suggestions = [
      {'icon': Icons.restaurant, 'text': 'Restaurants', 'color': Colors.orange},
      {
        'icon': Icons.local_gas_station,
        'text': 'Stations-service',
        'color': Colors.blue,
      },
      {
        'icon': Icons.local_pharmacy,
        'text': 'Pharmacies',
        'color': Colors.green,
      },
      {'icon': Icons.hotel, 'text': 'Hôtels', 'color': Colors.purple},
      {'icon': Icons.shopping_cart, 'text': 'Shopping', 'color': Colors.pink},
      {'icon': Icons.local_hospital, 'text': 'Hôpitaux', 'color': Colors.red},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return GestureDetector(
                    onTap: () => _performSearch(suggestion['text'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            suggestion['icon'] as IconData,
                            size: 32,
                            color: suggestion['color'] as Color,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            suggestion['text'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate(delay: Duration(milliseconds: 100 * index))
                  .fadeIn()
                  .scale(begin: const Offset(0.8, 0.8));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory(bool isDark) {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun historique',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recherches récentes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Effacer',
                  style: TextStyle(color: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final item = _searchHistory[index];
              return ListTile(
                    leading: Icon(
                      Icons.history,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    title: Text(
                      item,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.north_west,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onTap: () => _selectHistoryItem(item),
                  )
                  .animate(delay: Duration(milliseconds: 50 * index))
                  .fadeIn()
                  .slideX(begin: 0.3);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSuggestions(bool isDark) {
    // Générer des suggestions basées sur le texte saisi
    final query = _searchController.text.toLowerCase();
    final suggestions = _generateSuggestions(query);

    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune suggestion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
              leading: Icon(
                suggestion['icon'] as IconData,
                color: const Color(0xFF4CAF50),
              ),
              title: Text(
                suggestion['text'] as String,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: suggestion['subtitle'] != null
                  ? Text(
                      suggestion['subtitle'] as String,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    )
                  : null,
              onTap: () => _performSearch(suggestion['text'] as String),
            )
            .animate(delay: Duration(milliseconds: 50 * index))
            .fadeIn()
            .slideX(begin: 0.3);
      },
    );
  }

  List<Map<String, dynamic>> _generateSuggestions(String query) {
    final suggestions = <Map<String, dynamic>>[];

    // Base de données de lieux pour Lomé
    final places = [
      {
        'name': 'Grand Marché de Lomé',
        'type': 'Shopping',
        'icon': Icons.shopping_cart,
      },
      {
        'name': 'Monument de l\'Indépendance',
        'type': 'Attraction',
        'icon': Icons.place,
      },
      {'name': 'Plage de Lomé', 'type': 'Nature', 'icon': Icons.beach_access},
      {'name': 'CHU Campus', 'type': 'Hôpital', 'icon': Icons.local_hospital},
      {'name': 'Université de Lomé', 'type': 'Éducation', 'icon': Icons.school},
      {'name': 'Aéroport de Lomé', 'type': 'Transport', 'icon': Icons.flight},
      {
        'name': 'Gare routière de Lomé',
        'type': 'Transport',
        'icon': Icons.directions_bus,
      },
      {
        'name': 'Restaurant Akodessewa',
        'type': 'Restaurant',
        'icon': Icons.restaurant,
      },
      {'name': 'Hôtel Sarakawa', 'type': 'Hôtel', 'icon': Icons.hotel},
      {
        'name': 'Centre-ville de Lomé',
        'type': 'Zone',
        'icon': Icons.location_city,
      },
    ];

    // Recherche par nom
    for (final place in places) {
      if (place['name'].toString().toLowerCase().contains(query)) {
        suggestions.add({
          'text': place['name'],
          'subtitle': place['type'],
          'icon': place['icon'],
        });
      }
    }

    // Recherche par type si pas assez de résultats
    if (suggestions.length < 3) {
      for (final place in places) {
        if (place['type'].toString().toLowerCase().contains(query) &&
            !suggestions.any((s) => s['text'] == place['name'])) {
          suggestions.add({
            'text': place['name'],
            'subtitle': place['type'],
            'icon': place['icon'],
          });
        }
      }
    }

    // Suggestions génériques
    if (query.isNotEmpty && suggestions.length < 5) {
      final genericSuggestions = [
        {'text': '$query près de moi', 'icon': Icons.near_me},
        {'text': '$query à Lomé', 'icon': Icons.location_on},
        {'text': 'Restaurant $query', 'icon': Icons.restaurant},
        {'text': 'Hôtel $query', 'icon': Icons.hotel},
      ];

      for (final generic in genericSuggestions) {
        if (suggestions.length >= 8) break;
        suggestions.add(generic);
      }
    }

    return suggestions.take(8).toList();
  }
}
