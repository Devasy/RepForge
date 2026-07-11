// agent_graph.dart — Declarative graph definition for agent flows.
//
// A graph is a named collection of nodes with an entry point. The runtime
// walks the graph by executing nodes and following their NextNode transitions.

import 'agent_node.dart';

/// A declarative agent flow: a set of named nodes with an entry point.
class AgentGraph {
  /// Unique identifier for this graph (e.g. 'coach', 'optimizer').
  final String id;

  /// The node to start execution at.
  final String entryNodeId;

  /// All nodes in this graph, keyed by their [AgentNode.id].
  final Map<String, AgentNode> nodes;

  const AgentGraph({
    required this.id,
    required this.entryNodeId,
    required this.nodes,
  });

  /// Look up a node by id. Throws if not found.
  AgentNode node(String id) {
    final n = nodes[id];
    if (n == null) {
      throw StateError('AgentGraph "$id" has no node "$id"');
    }
    return n;
  }

  @override
  String toString() => 'AgentGraph($id, entry=$entryNodeId, ${nodes.length} nodes)';
}
