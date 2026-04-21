import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agent/agent_runtime.dart';
import '../services/agent/belief_updater.dart';
import '../services/agent/action_arbitration.dart';
import '../services/agent/character_cognitive_pass.dart';
import '../services/agent/character_input_assembly.dart';
import '../services/agent/cognitive_pass_executor.dart';
import '../services/agent/emotion_updater.dart';
import '../services/agent/embodiment_resolver.dart';
import '../services/agent/intent_agent.dart';
import '../services/agent/memory_access_protocol.dart';
import '../services/agent/scene_filtering_protocol.dart';
import '../services/agent/scene_state_extractor.dart';
import '../services/agent/surface_realizer.dart';

/// Provider for SceneStateExtractor - extracts structured scene models
/// from narrative text or world state JSON.
final sceneStateExtractorProvider = Provider<SceneStateExtractor>(
  (_) => const SceneStateExtractor(),
);

/// Provider for EmbodimentResolver - computes character embodiment state
/// including sensory capabilities, body constraints, and action feasibility.
final embodimentResolverProvider = Provider<EmbodimentResolver>(
  (_) => const EmbodimentResolver(),
);

/// Provider for SceneFilteringProtocol - filters scene entities and signals
/// based on character's sensory capabilities.
final sceneFilteringProtocolProvider = Provider<SceneFilteringProtocol>(
  (_) => const SceneFilteringProtocol(),
);

/// Provider for MemoryAccessProtocol - retrieves and ranks memories
/// accessible to a character based on permissions and relevance.
final memoryAccessProtocolProvider = Provider<MemoryAccessProtocol>(
  (_) => const MemoryAccessProtocol(),
);

/// Provider for CharacterInputAssembly - orchestrates the full cognitive
/// pass input assembly pipeline.
final characterInputAssemblyProvider = Provider<CharacterInputAssembly>(
  (ref) => CharacterInputAssembly(
    ref.watch(sceneStateExtractorProvider),
    ref.watch(embodimentResolverProvider),
    ref.watch(sceneFilteringProtocolProvider),
    ref.watch(memoryAccessProtocolProvider),
  ),
);

/// Provider for CharacterCognitivePass - executes the Perception -> Belief -> Intent
/// pipeline in a single model call.
final characterCognitivePassProvider = Provider<CharacterCognitivePass>(
  (_) => const CharacterCognitivePass(),
);

/// Provider for BeliefUpdater - updates character belief state based on
/// cognitive pass output.
final beliefUpdaterProvider = Provider<BeliefUpdater>(
  (_) => const BeliefUpdater(),
);

/// Provider for IntentAgent - coordinates intent execution and action planning.
final intentAgentProvider = Provider<IntentAgent>((_) => const IntentAgent());

/// Provider for ActionArbitration - resolves multi-character action order
/// and intent conflicts before rendering.
final actionArbitrationProvider = Provider<ActionArbitration>(
  (_) => const ActionArbitration(),
);

/// Provider for SurfaceRealizer - renders arbitrated actions into user-visible
/// text, dialogue blocks, and action descriptions.
final surfaceRealizerProvider = Provider<SurfaceRealizer>(
  (_) => const SurfaceRealizer(),
);

/// Provider for EmotionUpdater - updates character emotion state based on
/// cognitive pass output.
final emotionUpdaterProvider = Provider<EmotionUpdater>(
  (_) => const EmotionUpdater(),
);

/// Provider for CognitivePassExecutor - orchestrates the full cognitive
/// pass execution pipeline including belief, emotion, and intent updates.
final cognitivePassExecutorProvider = Provider<CognitivePassExecutor>(
  (ref) => CognitivePassExecutor(
    beliefUpdater: ref.watch(beliefUpdaterProvider),
    emotionUpdater: ref.watch(emotionUpdaterProvider),
    intentAgent: ref.watch(intentAgentProvider),
  ),
);

/// Provider for AgentRuntime - main loop orchestration for one turn.
final agentRuntimeProvider = Provider<AgentRuntime>(
  (ref) => AgentRuntime(
    sceneExtractor: ref.watch(sceneStateExtractorProvider),
    inputAssembly: ref.watch(characterInputAssemblyProvider),
    cognitivePassExecutor: ref.watch(cognitivePassExecutorProvider),
    actionArbitration: ref.watch(actionArbitrationProvider),
    surfaceRealizer: ref.watch(surfaceRealizerProvider),
  ),
);
