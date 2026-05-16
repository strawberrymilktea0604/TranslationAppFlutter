// Vocabulary Screen - UI for displaying and managing vocabulary.
// Shows list of saved translations for learning.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/vocabulary_providers.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Load vocabulary on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(vocabularyServiceProvider).getVocabularies(page: 1);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabularyService = ref.watch(vocabularyServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              vocabularyService.getVocabularies(
                page: 1,
                search: _searchController.text.isNotEmpty
                    ? _searchController.text
                    : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vocabularies...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          vocabularyService.getVocabularies(page: 1);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                vocabularyService.getVocabularies(
                  page: 1,
                  search: value.isNotEmpty ? value : null,
                );
              },
            ),
          ),

          // Vocabulary list
          Expanded(
            child: vocabularyService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vocabularyService.vocabularies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No vocabularies found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save translations to build your vocabulary',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: vocabularyService.vocabularies.length,
                    itemBuilder: (context, index) {
                      final vocab = vocabularyService.vocabularies[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          title: Text(
                            vocab.sourceText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                vocab.translatedText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.blue),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      '${vocab.sourceLanguage.toUpperCase()} → ${vocab.targetLanguage.toUpperCase()}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 8),
                                  if (vocab.translationType != null)
                                    Chip(
                                      label: Text(
                                        vocab.translationType!,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete?'),
                                  content: const Text(
                                    'Remove this vocabulary entry?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && context.mounted) {
                                try {
                                  await vocabularyService.removeFromVocabulary(
                                    vocab.id,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Removed from vocabulary',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Stats footer
          if (vocabularyService.vocabularies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Total: ${vocabularyService.totalCount} vocabularies',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
