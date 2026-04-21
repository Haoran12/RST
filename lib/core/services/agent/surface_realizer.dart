import '../../models/agent/cognitive_pass_io.dart';
import 'action_arbitration.dart';

/// Input contract for surface realization.
class SurfaceRealizerInput {
  const SurfaceRealizerInput({
    required this.sceneTurnId,
    required this.arbitrationResult,
    this.visibleSceneChanges = const [],
    this.speakerOrder = const [],
    this.toneProfile = const {},
    this.styleConstraints = const {},
  });

  final String sceneTurnId;
  final ActionArbitrationResult arbitrationResult;
  final List<String> visibleSceneChanges;
  final List<String> speakerOrder;
  final Map<String, dynamic> toneProfile;
  final Map<String, dynamic> styleConstraints;
}

/// Output contract for surface realization.
class SurfaceRealizerOutput {
  const SurfaceRealizerOutput({
    required this.renderedText,
    required this.dialogueBlocks,
    required this.visibleActionDescriptions,
  });

  final String renderedText;
  final List<DialogueBlock> dialogueBlocks;
  final List<String> visibleActionDescriptions;
}

/// Dialogue snippet ready for final rendering.
class DialogueBlock {
  const DialogueBlock({
    required this.characterId,
    required this.dialogue,
    required this.tone,
  });

  final String characterId;
  final String dialogue;
  final String tone;
}

/// Turn surface renderer.
///
/// This module renders only already-resolved outcomes from arbitration result.
class SurfaceRealizer {
  const SurfaceRealizer();

  SurfaceRealizerOutput render(SurfaceRealizerInput input) {
    final actionByCharacter = {
      for (final action in input.arbitrationResult.renderedActions)
        action.characterId: action,
    };

    final orderedCharacters = _resolveCharacterOrder(input);
    final visibleActionDescriptions = <String>[];
    final dialogueBlocks = <DialogueBlock>[];

    for (final characterId in orderedCharacters) {
      final action = actionByCharacter[characterId];
      if (action == null) {
        continue;
      }

      final actionLine = _buildActionLine(action);
      if (actionLine.isNotEmpty) {
        visibleActionDescriptions.add(actionLine);
      }

      final dialogue = action.dialogue.trim();
      if (dialogue.isEmpty || action.revealLevel == RevealLevel.silent) {
        continue;
      }

      dialogueBlocks.add(
        DialogueBlock(
          characterId: characterId,
          dialogue: dialogue,
          tone: _resolveTone(
            characterId: characterId,
            action: action,
            toneProfile: input.toneProfile,
          ),
        ),
      );
    }

    final textSegments = <String>[
      ...input.visibleSceneChanges
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
      ...visibleActionDescriptions,
      ...dialogueBlocks.map(
        (block) => '${block.characterId}：「${block.dialogue}」',
      ),
    ];

    return SurfaceRealizerOutput(
      renderedText: textSegments.join('\n'),
      dialogueBlocks: dialogueBlocks,
      visibleActionDescriptions: visibleActionDescriptions,
    );
  }

  List<String> _resolveCharacterOrder(SurfaceRealizerInput input) {
    final order = <String>[];

    for (final characterId in input.speakerOrder) {
      final normalized = characterId.trim();
      if (normalized.isNotEmpty && !order.contains(normalized)) {
        order.add(normalized);
      }
    }

    for (final execution in input.arbitrationResult.executionOrder) {
      if (!order.contains(execution.characterId)) {
        order.add(execution.characterId);
      }
    }

    for (final action in input.arbitrationResult.renderedActions) {
      if (!order.contains(action.characterId)) {
        order.add(action.characterId);
      }
    }

    return order;
  }

  String _buildActionLine(ArbitratedAction action) {
    final outwardAction = action.outwardAction.trim();
    if (outwardAction.isEmpty) {
      return '';
    }

    if (action.visibleBehavior.isEmpty) {
      return '${action.characterId}: $outwardAction';
    }

    final behaviorText = action.visibleBehavior
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('，');
    if (behaviorText.isEmpty) {
      return '${action.characterId}: $outwardAction';
    }

    return '${action.characterId}: $outwardAction（$behaviorText）';
  }

  String _resolveTone({
    required String characterId,
    required ArbitratedAction action,
    required Map<String, dynamic> toneProfile,
  }) {
    final toneConfig = toneProfile[characterId];
    if (toneConfig is String && toneConfig.trim().isNotEmpty) {
      return toneConfig.trim();
    }
    if (toneConfig is Map) {
      final value = '${toneConfig['tone'] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    for (final behavior in action.visibleBehavior) {
      if (behavior.startsWith('语气:')) {
        final tone = behavior.substring(3).trim();
        if (tone.isNotEmpty) {
          return tone;
        }
      }
    }

    return 'neutral';
  }
}
