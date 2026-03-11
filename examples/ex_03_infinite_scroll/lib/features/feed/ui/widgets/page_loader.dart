import 'package:flutter/material.dart';

/// Shown at the bottom (or top) of the feed list while a page is loading.
///
/// Designed to sit inside a [SliverList] item or a [SliverToBoxAdapter]
/// so existing items remain visible during the fetch.
class PageLoader extends StatelessWidget {
  const PageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
