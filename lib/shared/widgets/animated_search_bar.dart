import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../features/search/providers/search_provider.dart';

class AnimatedSearchBar extends StatefulWidget {
  final AnimationController controller;
  final Function(String) onSearch;
  final Function(SearchResult) onResultSelected;
  final List<SearchResult> results;
  final bool isLoading;

  const AnimatedSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onResultSelected,
    required this.results,
    required this.isLoading,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barre de recherche principale
        Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _textController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _textController.clear();
                            widget.onSearch('');
                            setState(() {
                              _isExpanded = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  widget.onSearch(value);
                  setState(() {
                    _isExpanded = value.isNotEmpty && widget.results.isNotEmpty;
                  });
                },
                onTap: () {
                  setState(() {
                    _isExpanded =
                        _textController.text.isNotEmpty &&
                        widget.results.isNotEmpty;
                  });
                },
              ),
            )
            .animate(controller: widget.controller)
            .slideY(begin: -1, duration: 300.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 400.ms),

        // Résultats de recherche
        if (_isExpanded && widget.results.isNotEmpty)
          Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      for (
                        int i = 0;
                        i < widget.results.length.clamp(0, 5);
                        i++
                      )
                        _buildResultItem(widget.results[i], i),
                    ],
                  ),
                ),
              )
              .animate()
              .slideY(begin: -0.3, duration: 300.ms, curve: Curves.easeOutCubic)
              .fadeIn(duration: 200.ms),
      ],
    );
  }

  Widget _buildResultItem(SearchResult result, int index) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              widget.onResultSelected(result);
              _textController.text = result.name;
              setState(() {
                _isExpanded = false;
              });
              _focusNode.unfocus();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: index < widget.results.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForType(result.type),
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (result.address != null)
                          Text(
                            result.address!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 50))
        .slideX(begin: 0.3, duration: 200.ms)
        .fadeIn(duration: 150.ms);
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'cafe':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'bank':
        return Icons.account_balance;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'shop':
      case 'store':
        return Icons.store;
      default:
        return Icons.place;
    }
  }
}
