import 'package:flutter/material.dart';

class BreadcrumbKey extends StatelessWidget {
  final String queryKey;
  const BreadcrumbKey({super.key, required this.queryKey});

  List<String> get _segments =>
      queryKey.split(RegExp(r'[./\[\],]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final segs = _segments;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < segs.length; i++) ...[
          Text(segs[i],
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          if (i < segs.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('›',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  )),
            ),
        ],
      ],
    );
  }
}
