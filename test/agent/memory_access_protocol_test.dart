import 'package:flutter_test/flutter_test.dart';
import 'package:rst/core/models/agent/filtered_scene_view.dart';
import 'package:rst/core/models/agent/memory_entry.dart';
import 'package:rst/core/services/agent/memory_access_protocol.dart';

void main() {
  group('MemoryAccessProtocol', () {
    const protocol = MemoryAccessProtocol();

    group('permission filtering', () {
      test('private memory only accessible to owner', () {
        final memory = MemoryEntry(
          memoryId: 'private_001',
          content: 'Secret information',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        );

        expect(memory.canAccess('alice'), isTrue);
        expect(memory.canAccess('bob'), isFalse);
      });

      test('shared memory accessible to knownBy list', () {
        final memory = MemoryEntry(
          memoryId: 'shared_001',
          content: 'Shared event',
          ownerCharacterId: 'alice',
          knownBy: const ['alice', 'bob'],
          visibility: MemoryVisibility.shared,
          createdAt: DateTime.now(),
        );

        expect(memory.canAccess('alice'), isTrue);
        expect(memory.canAccess('bob'), isTrue);
        expect(memory.canAccess('charlie'), isFalse);
      });

      test('public memory accessible to all', () {
        final memory = MemoryEntry(
          memoryId: 'public_001',
          content: 'Public fact',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.public,
          createdAt: DateTime.now(),
        );

        expect(memory.canAccess('alice'), isTrue);
        expect(memory.canAccess('bob'), isTrue);
        expect(memory.canAccess('anyone'), isTrue);
      });

      test('filterByPermission returns only accessible memories', () {
        final memories = [
          MemoryEntry(
            memoryId: 'private_alice',
            content: 'Alice secret',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'shared_ab',
            content: 'Shared between Alice and Bob',
            ownerCharacterId: 'alice',
            knownBy: const ['alice', 'bob'],
            visibility: MemoryVisibility.shared,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'private_charlie',
            content: 'Charlie secret',
            ownerCharacterId: 'charlie',
            knownBy: const ['charlie'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'public_001',
            content: 'Public information',
            ownerCharacterId: 'dave',
            knownBy: const ['dave'],
            visibility: MemoryVisibility.public,
            createdAt: DateTime.now(),
          ),
        ];

        final bobAccessible = protocol.filterByPermission(memories: memories, characterId: 'bob');
        expect(bobAccessible.length, equals(2)); // shared_ab and public_001

        final charlieAccessible = protocol.filterByPermission(memories: memories, characterId: 'charlie');
        expect(charlieAccessible.length, equals(2)); // private_charlie and public_001
      });
    });

    group('relevance scoring', () {
      test('entity overlap increases relevance', () {
        final memory = MemoryEntry(
          memoryId: 'entity_memory',
          content: 'Met John at the market',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        );

        final contextWithEntity = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          activeEntities: const ['John', 'market'],
        );

        final contextWithoutEntity = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          activeEntities: const ['Bob', 'temple'],
        );

        final scoreWithEntity = protocol.calculateRelevance(memory: memory, context: contextWithEntity);
        final scoreWithoutEntity = protocol.calculateRelevance(memory: memory, context: contextWithoutEntity);

        expect(scoreWithEntity, greaterThan(scoreWithoutEntity));
      });

      test('goal relevance increases score', () {
        final memory = MemoryEntry(
          memoryId: 'goal_memory',
          content: 'The treasure is hidden in the cave',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
        );

        final contextWithGoal = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          currentGoals: const ['find the treasure', 'explore the cave'],
        );

        final contextWithoutGoal = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          currentGoals: const ['buy food', 'rest at inn'],
        );

        final scoreWithGoal = protocol.calculateRelevance(memory: memory, context: contextWithGoal);
        final scoreWithoutGoal = protocol.calculateRelevance(memory: memory, context: contextWithoutGoal);

        expect(scoreWithGoal, greaterThan(scoreWithoutGoal));
      });

      test('emotional resonance affects score', () {
        final highEmotionMemory = MemoryEntry(
          memoryId: 'emotional_memory',
          content: 'Terrifying encounter with the beast',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          emotionalWeight: 0.9,
          createdAt: DateTime.now(),
        );

        final lowEmotionMemory = MemoryEntry(
          memoryId: 'calm_memory',
          content: 'Peaceful walk in the garden',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          emotionalWeight: 0.1,
          createdAt: DateTime.now(),
        );

        final fearfulContext = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          currentEmotions: const {'fear': 0.8},
        );

        final calmContext = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          currentEmotions: const {'calm': 0.2},
        );

        // High emotion memory should score higher in fearful context
        final highEmotionScore = protocol.calculateRelevance(memory: highEmotionMemory, context: fearfulContext);
        final lowEmotionScore = protocol.calculateRelevance(memory: lowEmotionMemory, context: fearfulContext);

        expect(highEmotionScore, greaterThan(lowEmotionScore));
      });

      test('recent memories score higher', () {
        final recentMemory = MemoryEntry(
          memoryId: 'recent',
          content: 'Just happened',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        );

        final oldMemory = MemoryEntry(
          memoryId: 'old',
          content: 'Long ago',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          lastAccessedAt: DateTime.now().subtract(const Duration(days: 30)),
        );

        final context = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
        );

        final recentScore = protocol.calculateRelevance(memory: recentMemory, context: context);
        final oldScore = protocol.calculateRelevance(memory: oldMemory, context: context);

        expect(recentScore, greaterThan(oldScore));
      });
    });

    group('ranking', () {
      test('memories are ranked by relevance score', () {
        final memories = [
          MemoryEntry(
            memoryId: 'low_relevance',
            content: 'Unrelated information',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          MemoryEntry(
            memoryId: 'high_relevance',
            content: 'Important information about John',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            emotionalWeight: 0.8,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'medium_relevance',
            content: 'Some context about the situation',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ];

        final context = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          activeEntities: const ['John'],
          currentEmotions: const {'fear': 0.7},
        );

        final ranked = protocol.rankByRelevance(
          memories: memories,
          context: context,
          maxCount: 10,
        );

        // High relevance should be first
        expect(ranked.first.memoryId, equals('high_relevance'));
      });

      test('maxCount limits returned memories', () {
        final memories = List.generate(20, (i) => MemoryEntry(
          memoryId: 'memory_$i',
          content: 'Memory content $i',
          ownerCharacterId: 'alice',
          knownBy: const ['alice'],
          visibility: MemoryVisibility.private,
          createdAt: DateTime.now().subtract(Duration(hours: i)),
        ));

        final context = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
        );

        final ranked = protocol.rankByRelevance(
          memories: memories,
          context: context,
          maxCount: 5,
        );

        expect(ranked.length, equals(5));
      });

      test('relevanceThreshold filters low-scoring memories', () {
        final memories = [
          MemoryEntry(
            memoryId: 'relevant',
            content: 'John is here',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'irrelevant',
            content: 'Random unrelated text',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now().subtract(const Duration(days: 100)),
          ),
        ];

        final context = MemoryAccessContext(
          filteredSceneView: const FilteredSceneView(
            characterId: 'alice',
            sceneTurnId: 'turn_001',
            spatialContext: SpatialContext(),
          ),
          activeEntities: const ['John'],
        );

        final ranked = protocol.rankByRelevance(
          memories: memories,
          context: context,
          maxCount: 10,
          relevanceThreshold: 0.3,
        );

        // Only the relevant memory should pass the threshold
        expect(ranked.length, equals(1));
        expect(ranked.first.memoryId, equals('relevant'));
      });
    });

    group('full retrieval', () {
      test('retrieve returns correct result', () {
        final memories = [
          MemoryEntry(
            memoryId: 'alice_private',
            content: 'Alice secret',
            ownerCharacterId: 'alice',
            knownBy: const ['alice'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'shared',
            content: 'Shared memory',
            ownerCharacterId: 'alice',
            knownBy: const ['alice', 'bob'],
            visibility: MemoryVisibility.shared,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'charlie_private',
            content: 'Charlie secret',
            ownerCharacterId: 'charlie',
            knownBy: const ['charlie'],
            visibility: MemoryVisibility.private,
            createdAt: DateTime.now(),
          ),
          MemoryEntry(
            memoryId: 'public',
            content: 'Public fact',
            ownerCharacterId: 'dave',
            knownBy: const ['dave'],
            visibility: MemoryVisibility.public,
            createdAt: DateTime.now(),
          ),
        ];

        final request = MemoryAccessRequest(
          characterId: 'bob',
          sceneTurnId: 'turn_001',
          allMemories: memories,
          currentContext: MemoryAccessContext(
            filteredSceneView: const FilteredSceneView(
              characterId: 'bob',
              sceneTurnId: 'turn_001',
              spatialContext: SpatialContext(),
            ),
          ),
          maxMemories: 10,
        );

        final result = protocol.retrieve(request);

        expect(result.totalAccessible, equals(2)); // shared and public
        expect(result.filteredByPermission, equals(2)); // alice_private and charlie_private
        expect(result.memories.length, equals(2));
      });
    });
  });
}
