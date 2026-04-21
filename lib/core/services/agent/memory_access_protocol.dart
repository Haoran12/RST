import '../../models/agent/filtered_scene_view.dart';
import '../../models/agent/memory_entry.dart';

/// Context for memory relevance scoring.
class MemoryAccessContext {
  const MemoryAccessContext({
    required this.filteredSceneView,
    this.activeEntities = const [],
    this.recentTopics = const [],
    this.currentGoals = const [],
    this.currentEmotions = const {},
  });

  final FilteredSceneView filteredSceneView;
  final List<String> activeEntities;
  final List<String> recentTopics;
  final List<String> currentGoals;
  final Map<String, double> currentEmotions;
}

/// Request for memory access.
class MemoryAccessRequest {
  const MemoryAccessRequest({
    required this.characterId,
    required this.sceneTurnId,
    required this.allMemories,
    required this.currentContext,
    this.maxMemories = 10,
    this.relevanceThreshold = 0.2,
  });

  final String characterId;
  final String sceneTurnId;
  final List<MemoryEntry> allMemories;
  final MemoryAccessContext currentContext;
  final int maxMemories;
  final double relevanceThreshold;
}

/// Result of memory access.
class MemoryAccessResult {
  const MemoryAccessResult({
    required this.memories,
    required this.totalAccessible,
    required this.filteredByPermission,
  });

  final List<MemoryEntry> memories;
  final int totalAccessible;
  final int filteredByPermission;
}

/// Retrieves and ranks memories accessible to a character.
///
/// This is a pure programmatic service that:
/// - Filters memories by permission (knownBy contains characterId or visibility is public)
/// - Calculates relevance scores based on entity overlap, goal relevance, emotional resonance
/// - Ranks memories by relevance score
class MemoryAccessProtocol {
  const MemoryAccessProtocol();

  /// Retrieve accessible memories for the character.
  MemoryAccessResult retrieve(MemoryAccessRequest request) {
    // Step 1: Filter by permission
    final accessibleMemories = filterByPermission(
      memories: request.allMemories,
      characterId: request.characterId,
    );

    final filteredByPermission = request.allMemories.length - accessibleMemories.length;

    // Step 2: Rank by relevance
    final rankedMemories = rankByRelevance(
      memories: accessibleMemories,
      context: request.currentContext,
      maxCount: request.maxMemories,
      relevanceThreshold: request.relevanceThreshold,
    );

    return MemoryAccessResult(
      memories: rankedMemories,
      totalAccessible: accessibleMemories.length,
      filteredByPermission: filteredByPermission,
    );
  }

  /// Filter memories by permission (knownBy contains characterId).
  List<MemoryEntry> filterByPermission({
    required List<MemoryEntry> memories,
    required String characterId,
  }) {
    return memories.where((memory) => memory.canAccess(characterId)).toList();
  }

  /// Calculate relevance score for a memory.
  double calculateRelevance({
    required MemoryEntry memory,
    required MemoryAccessContext context,
  }) {
    double score = 0.0;

    // 1. Entity mention overlap (30% weight)
    final entityOverlap = _calculateEntityOverlap(memory, context);
    score += entityOverlap * 0.30;

    // 2. Goal relevance (25% weight)
    final goalRelevance = _calculateGoalRelevance(memory, context);
    score += goalRelevance * 0.25;

    // 3. Emotional resonance (25% weight)
    final emotionalResonance = _calculateEmotionalResonance(memory, context);
    score += emotionalResonance * 0.25;

    // 4. Recency (20% weight)
    final recency = _calculateRecency(memory);
    score += recency * 0.20;

    return score.clamp(0.0, 1.0);
  }

  /// Rank memories by relevance score.
  List<MemoryEntry> rankByRelevance({
    required List<MemoryEntry> memories,
    required MemoryAccessContext context,
    required int maxCount,
    double relevanceThreshold = 0.0,
  }) {
    // Calculate scores for all memories
    final scoredMemories = <MapEntry<MemoryEntry, double>>[];
    for (final memory in memories) {
      final score = calculateRelevance(memory: memory, context: context);
      if (score >= relevanceThreshold) {
        scoredMemories.add(MapEntry(memory, score));
      }
    }

    // Sort by score descending
    scoredMemories.sort((a, b) => b.value.compareTo(a.value));

    // Return top memories
    return scoredMemories.take(maxCount).map((e) => e.key).toList();
  }

  // === Private helper methods ===

  double _calculateEntityOverlap(MemoryEntry memory, MemoryAccessContext context) {
    if (context.activeEntities.isEmpty) return 0.0;

    final memoryLower = memory.content.toLowerCase();
    int overlapCount = 0;

    for (final entity in context.activeEntities) {
      if (memoryLower.contains(entity.toLowerCase())) {
        overlapCount++;
      }
    }

    // Also check visible entities from filtered scene view
    for (final entity in context.filteredSceneView.visibleEntities) {
      // Check if entity ID or related content is mentioned
      if (memoryLower.contains(entity.entityId.toLowerCase())) {
        overlapCount++;
      }
    }

    return (overlapCount / context.activeEntities.length).clamp(0.0, 1.0);
  }

  double _calculateGoalRelevance(MemoryEntry memory, MemoryAccessContext context) {
    if (context.currentGoals.isEmpty) return 0.0;

    final memoryLower = memory.content.toLowerCase();
    int relevanceCount = 0;

    for (final goal in context.currentGoals) {
      // Extract keywords from goal
      final keywords = _extractKeywords(goal);
      for (final keyword in keywords) {
        if (memoryLower.contains(keyword.toLowerCase())) {
          relevanceCount++;
          break; // Count each goal only once
        }
      }
    }

    return (relevanceCount / context.currentGoals.length).clamp(0.0, 1.0);
  }

  double _calculateEmotionalResonance(MemoryEntry memory, MemoryAccessContext context) {
    if (context.currentEmotions.isEmpty) return 0.0;

    // High emotional weight memories resonate more when character is emotional
    final maxEmotion = context.currentEmotions.values.fold(0.0, (a, b) => a > b ? a : b);

    // Resonance is higher when memory emotional weight matches current emotional intensity
    final resonance = 1.0 - (memory.emotionalWeight - maxEmotion).abs();

    return resonance.clamp(0.0, 1.0);
  }

  double _calculateRecency(MemoryEntry memory) {
    final now = DateTime.now();
    final lastAccessed = memory.lastAccessedAt ?? memory.createdAt;
    final hoursSinceAccess = now.difference(lastAccessed).inHours;

    // Recency decays over time: 1/(1 + hours * 0.01)
    // Full recency for recent memories, decaying over days
    return 1.0 / (1.0 + hoursSinceAccess * 0.01);
  }

  List<String> _extractKeywords(String text) {
    // Simple keyword extraction: split by common delimiters and filter short words
    return text
        .toLowerCase()
        .split(RegExp(r'[,\s\-，。！？]+'))
        .where((word) => word.length >= 2)
        .toList();
  }
}
