import 'package:flutter/material.dart';

import 'search.dart';

class FeedScreen extends StatelessWidget {
  final bool showSearchField;

  const FeedScreen({
    super.key,
    this.showSearchField = true,
  });

  @override
  Widget build(BuildContext context) {
    return SearchScreen(showSearchField: showSearchField);
  }
}
