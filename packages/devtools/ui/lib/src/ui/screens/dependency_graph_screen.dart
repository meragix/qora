import 'package:flutter/material.dart';
import 'package:qora_devtools_ui/src/domain/dependency_notifier.dart';

/// Screen that displays the inferred query→mutation dependency graph.
///
/// Mutations appear as red nodes on the left column, queries as blue nodes
/// on the right. Directed edges (cubic Bézier arrows) connect each mutation
/// to the queries it invalidated.
///
/// The graph is wrapped in an [InteractiveViewer] for pan/zoom support.
/// Tapping a node highlights it and shows a detail panel below.
class DependencyGraphScreen extends StatefulWidget {
  /// Creates the dependency graph screen.
  const DependencyGraphScreen({super.key, required this.notifier});

  /// Notifier providing nodes and edges.
  final DependencyNotifier notifier;

  @override
  State<DependencyGraphScreen> createState() => _DependencyGraphScreenState();
}

class _DependencyGraphScreenState extends State<DependencyGraphScreen> {
  String _filter = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notifier,
      builder: (context, _) {
        final allNodes = widget.notifier.nodes;
        final allEdges = widget.notifier.edges;

        final nodes = _filter.isEmpty
            ? allNodes
            : allNodes
                .where((n) =>
                    n.label.toLowerCase().contains(_filter.toLowerCase()))
                .toList(growable: false);

        final nodeIds = {for (final n in nodes) n.id};
        final edges = allEdges
            .where((e) =>
                nodeIds.contains(e.fromMutationId) &&
                nodeIds.contains(e.toQueryKey))
            .toList(growable: false);

        final selected = _selectedId != null
            ? allNodes.where((n) => n.id == _selectedId).firstOrNull
            : null;

        return Column(
          children: <Widget>[
            // ── Toolbar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _filter = v),
                      decoration: const InputDecoration(
                        hintText: 'Filter by key…',
                        prefixIcon: Icon(Icons.search, size: 16),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.notifier.clear,
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            // ── Legend ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: <Widget>[
                  _LegendDot(color: _kMutationColor, label: 'Mutations'),
                  const SizedBox(width: 16),
                  _LegendDot(color: _kQueryColor, label: 'Queries'),
                  const Spacer(),
                  Text(
                    '${nodes.length} nodes · ${edges.length} edges',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            // ── Graph canvas ─────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: nodes.isEmpty
                  ? const Center(
                      child: Text(
                        'No dependency data yet.\nPerform some mutations and watch queries invalidate.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(64),
                      minScale: 0.3,
                      maxScale: 4,
                      child: CustomPaint(
                        size: _computeCanvasSize(nodes),
                        painter: _GraphPainter(
                          nodes: nodes,
                          edges: edges,
                          selectedId: _selectedId,
                        ),
                        child: _GraphHitArea(
                          nodes: nodes,
                          onTap: (id) =>
                              setState(() => _selectedId = id == _selectedId ? null : id),
                        ),
                      ),
                    ),
            ),
            // ── Detail panel ─────────────────────────────────────────────
            if (selected != null) ...<Widget>[
              const Divider(height: 1),
              _DetailPanel(
                node: selected,
                edges: allEdges,
                onClose: () => setState(() => _selectedId = null),
              ),
            ],
          ],
        );
      },
    );
  }

  Size _computeCanvasSize(List<GraphNode> nodes) {
    final mutations = nodes.where((n) => n.isMutation).length;
    final queries = nodes.where((n) => !n.isMutation).length;
    final rows = (mutations > queries ? mutations : queries).clamp(1, 100);
    return Size(500, rows * (_kNodeHeight + _kRowGap) + 48);
  }
}

// ── Layout constants ──────────────────────────────────────────────────────────

const double _kNodeWidth = 160;
const double _kNodeHeight = 28;
const double _kRowGap = 16;
const double _kMutationX = 16;
const double _kQueryX = 320;
const Color _kMutationColor = Color(0xFFEF4444);
const Color _kQueryColor = Color(0xFF3B82F6);
const Color _kEdgeColor = Color(0xFF94A3B8);
const double _kTopPad = 24;

// ── Node layout helpers ───────────────────────────────────────────────────────

List<GraphNode> _mutations(List<GraphNode> nodes) =>
    nodes.where((n) => n.isMutation).toList(growable: false);
List<GraphNode> _queries(List<GraphNode> nodes) =>
    nodes.where((n) => !n.isMutation).toList(growable: false);

Offset _nodeCenter(GraphNode node, List<GraphNode> nodes) {
  final muts = _mutations(nodes);
  final qrys = _queries(nodes);
  if (node.isMutation) {
    final i = muts.indexOf(node);
    return Offset(
      _kMutationX + _kNodeWidth / 2,
      _kTopPad + i * (_kNodeHeight + _kRowGap) + _kNodeHeight / 2,
    );
  } else {
    final i = qrys.indexOf(node);
    return Offset(
      _kQueryX + _kNodeWidth / 2,
      _kTopPad + i * (_kNodeHeight + _kRowGap) + _kNodeHeight / 2,
    );
  }
}

Rect _nodeRect(GraphNode node, List<GraphNode> nodes) {
  final c = _nodeCenter(node, nodes);
  return Rect.fromCenter(center: c, width: _kNodeWidth, height: _kNodeHeight);
}

// ── Graph painter ─────────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedId,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawEdges(Canvas canvas) {
    final paint = Paint()
      ..color = _kEdgeColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = _kEdgeColor
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromNode = nodes.where((n) => n.id == edge.fromMutationId).firstOrNull;
      final toNode = nodes.where((n) => n.id == edge.toQueryKey).firstOrNull;
      if (fromNode == null || toNode == null) continue;

      final from = _nodeCenter(fromNode, nodes)
          .translate(_kNodeWidth / 2, 0);
      final to = _nodeCenter(toNode, nodes)
          .translate(-_kNodeWidth / 2, 0);

      final cp1 = Offset(from.dx + 60, from.dy);
      final cp2 = Offset(to.dx - 60, to.dy);

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);

      canvas.drawPath(path, paint);

      // Arrowhead
      final dir = (to - Offset(cp2.dx, cp2.dy)).normalized;
      _drawArrowhead(canvas, to, dir, arrowPaint);
    }
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Offset dir, Paint paint) {
    const len = 8.0;
    const half = 4.0;
    final perp = Offset(-dir.dy, dir.dx);
    final base = tip - dir.scale(len, len);
    final p1 = base + perp.scale(half, half);
    final p2 = base - perp.scale(half, half);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final rect = _nodeRect(node, nodes);
      final isSelected = node.id == selectedId;
      final color = node.isMutation ? _kMutationColor : _kQueryColor;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // Fill
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: 0.15),
      );

      // Border
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isSelected ? color : color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2 : 1,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: _truncate(node.label, 22),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: _kNodeWidth - 8);

      tp.paint(
        canvas,
        rect.topLeft + Offset(4, (rect.height - tp.height) / 2),
      );
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.nodes != nodes || old.edges != edges || old.selectedId != selectedId;
}

// ── Hit area ──────────────────────────────────────────────────────────────────

class _GraphHitArea extends StatelessWidget {
  const _GraphHitArea({required this.nodes, required this.onTap});

  final List<GraphNode> nodes;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: nodes.map((node) {
        final rect = _nodeRect(node, nodes);
        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: GestureDetector(
            onTap: () => onTap(node.id),
            child: const ColoredBox(color: Colors.transparent),
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ── Detail panel ──────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.node,
    required this.edges,
    required this.onClose,
  });

  final GraphNode node;
  final List<GraphEdge> edges;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final related = node.isMutation
        ? edges
            .where((e) => e.fromMutationId == node.id)
            .map((e) => e.toQueryKey)
            .toList(growable: false)
        : edges
            .where((e) => e.toQueryKey == node.id)
            .map((e) => e.fromMutationId)
            .toList(growable: false);

    final relatedLabel = node.isMutation
        ? 'Invalidates ${related.length} quer${related.length == 1 ? 'y' : 'ies'}'
        : 'Invalidated by ${related.length} mutation${related.length == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _LegendDot(
                color: node.isMutation ? _kMutationColor : _kQueryColor,
                label: node.isMutation ? 'Mutation' : 'Query',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.label,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            relatedLabel,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (related.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: related
                  .map(
                    (r) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        r.length > 30 ? '${r.substring(0, 29)}…' : r,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Offset helpers ────────────────────────────────────────────────────────────

extension _OffsetExt on Offset {
  Offset get normalized {
    final len = distance;
    return len == 0 ? Offset.zero : Offset(dx / len, dy / len);
  }
}
