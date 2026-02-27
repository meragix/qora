import 'package:flutter/material.dart';

/// Simple metadata table used in the mutation inspector.
class MetadataTable extends StatelessWidget {
  /// Creates metadata table.
  const MetadataTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: const <TableRow>[
        TableRow(children: <Widget>[Text('Created At'), Text('-')]),
        TableRow(children: <Widget>[Text('Submitted At'), Text('-')]),
        TableRow(children: <Widget>[Text('Updated At'), Text('-')]),
        TableRow(children: <Widget>[Text('Retry Count'), Text('0')]),
      ],
    );
  }
}
