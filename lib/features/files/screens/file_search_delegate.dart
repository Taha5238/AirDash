import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileSearchDelegate extends SearchDelegate {
  final List<FileItem> files;
  final Function(String) onSearch;

  FileSearchDelegate(this.files, this.onSearch);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch('');
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return Container(); // Search happens in parent
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = files.where((file) => file.name.toLowerCase().contains(query.toLowerCase())).toList();
    
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final file = suggestions[index];
        return ListTile(
          title: Text(file.name),
          onTap: () {
            query = file.name;
            onSearch(query);
            close(context, null);
          },
        );
      },
    );
  }
}
