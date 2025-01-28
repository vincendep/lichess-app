import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/over_the_board/over_the_board_clock.dart';
import 'package:lichess_mobile/src/model/over_the_board/over_the_board_game_controller.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/over_the_board_preferences.dart';
import 'package:lichess_mobile/src/utils/immersive_mode.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/game/game_player.dart';
import 'package:lichess_mobile/src/view/game/game_result_dialog.dart';
import 'package:lichess_mobile/src/view/over_the_board/configure_over_the_board_game.dart';
import 'package:lichess_mobile/src/widgets/board_table.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/clock.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';

class OverTheBoardScreen extends StatelessWidget {
  const OverTheBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Over the board'), // TODO: l10n
        actions: [
          AppBarIconButton(
            onPressed: () => showConfigureDisplaySettings(context),
            semanticsLabel: context.l10n.settingsSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: const _Body(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _boardKey = GlobalKey(debugLabel: 'boardOnOverTheBoardScreen');

  Side orientation = Side.white;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      showConfigureGameSheet(context, isDismissible: false);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(overTheBoardGameControllerProvider);
    final boardPreferences = ref.watch(boardPreferencesProvider);

    final overTheBoardPrefs = ref.watch(overTheBoardPreferencesProvider);

    ref.listen(overTheBoardClockProvider.select((value) => value.flagSide), (previous, flagSide) {
      if (previous == null && flagSide != null) {
        ref.read(overTheBoardGameControllerProvider.notifier).onFlag(flagSide);
      }
    });

    ref.listen(overTheBoardGameControllerProvider, (previous, newGameState) {
      if (previous?.finished == false && newGameState.finished) {
        ref.read(overTheBoardClockProvider.notifier).pause();
        Timer(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            showAdaptiveDialog<void>(
              context: context,
              builder:
                  (context) => OverTheBoardGameResultDialog(
                    game: newGameState.game,
                    onRematch: () {
                      setState(() {
                        orientation = orientation.opposite;
                        ref.read(overTheBoardGameControllerProvider.notifier).rematch();
                        ref.read(overTheBoardClockProvider.notifier).restart();
                        Navigator.pop(context);
                      });
                    },
                  ),
              barrierDismissible: true,
            );
          }
        });
      }
    });

    return WakelockWidget(
      child: PopScope(
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: BoardTable(
                  key: _boardKey,
                  topTable: _Player(
                    side: orientation.opposite,
                    upsideDown:
                        !overTheBoardPrefs.flipPiecesAfterMove || orientation != gameState.turn,
                    clockKey: const ValueKey('topClock'),
                  ),
                  bottomTable: _Player(
                    side: orientation,
                    upsideDown:
                        overTheBoardPrefs.flipPiecesAfterMove && orientation != gameState.turn,
                    clockKey: const ValueKey('bottomClock'),
                  ),
                  orientation: orientation,
                  fen: gameState.currentPosition.fen,
                  lastMove: gameState.lastMove,
                  gameData: GameData(
                    isCheck: boardPreferences.boardHighlights && gameState.currentPosition.isCheck,
                    playerSide:
                        gameState.game.finished
                            ? PlayerSide.none
                            : gameState.turn == Side.white
                            ? PlayerSide.white
                            : PlayerSide.black,
                    sideToMove: gameState.turn,
                    validMoves: gameState.legalMoves,
                    onPromotionSelection:
                        ref.read(overTheBoardGameControllerProvider.notifier).onPromotionSelection,
                    promotionMove: gameState.promotionMove,
                    onMove: (move, {isDrop}) {
                      ref
                          .read(overTheBoardClockProvider.notifier)
                          .onMove(newSideToMove: gameState.turn.opposite);
                      ref.read(overTheBoardGameControllerProvider.notifier).makeMove(move);
                    },
                  ),
                  moves: gameState.moves,
                  currentMoveIndex: gameState.stepCursor,
                  boardSettingsOverrides: BoardSettingsOverrides(
                    drawShape: const DrawShapeOptions(enable: false),
                    pieceOrientationBehavior:
                        overTheBoardPrefs.flipPiecesAfterMove
                            ? PieceOrientationBehavior.sideToPlay
                            : PieceOrientationBehavior.opponentUpsideDown,
                    pieceAssets:
                        overTheBoardPrefs.symmetricPieces ? PieceSet.symmetric.assets : null,
                  ),
                ),
              ),
            ),
            _BottomBar(
              onFlipBoard: () {
                setState(() {
                  orientation = orientation.opposite;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.onFlipBoard});

  final VoidCallback onFlipBoard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(overTheBoardGameControllerProvider);

    final clock = ref.watch(overTheBoardClockProvider);

    return PlatformBottomBar(
      children: [
        BottomBarButton(
          label: 'Configure game',
          onTap: () => showConfigureGameSheet(context, isDismissible: true),
          icon: Icons.add,
        ),
        BottomBarButton(
          key: const Key('flip-button'),
          label: context.l10n.flipBoard,
          onTap: onFlipBoard,
          icon: CupertinoIcons.arrow_2_squarepath,
        ),
        if (!clock.timeIncrement.isInfinite)
          BottomBarButton(
            label: clock.active ? 'Pause' : 'Resume',
            onTap:
                gameState.finished
                    ? null
                    : () {
                      if (clock.active) {
                        ref.read(overTheBoardClockProvider.notifier).pause();
                      } else {
                        ref.read(overTheBoardClockProvider.notifier).resume(gameState.turn);
                      }
                    },
            icon: clock.active ? CupertinoIcons.pause : CupertinoIcons.play,
          ),
        BottomBarButton(
          label: 'Previous',
          onTap:
              gameState.canGoBack
                  ? () {
                    ref.read(overTheBoardGameControllerProvider.notifier).goBack();
                    if (clock.active) {
                      ref
                          .read(overTheBoardClockProvider.notifier)
                          .switchSide(newSideToMove: gameState.turn.opposite, addIncrement: false);
                    }
                  }
                  : null,
          icon: CupertinoIcons.chevron_back,
        ),
        BottomBarButton(
          label: 'Next',
          onTap:
              gameState.canGoForward
                  ? () {
                    ref.read(overTheBoardGameControllerProvider.notifier).goForward();
                    if (clock.active) {
                      ref
                          .read(overTheBoardClockProvider.notifier)
                          .switchSide(newSideToMove: gameState.turn.opposite, addIncrement: false);
                    }
                  }
                  : null,
          icon: CupertinoIcons.chevron_forward,
        ),
      ],
    );
  }
}

class _Player extends ConsumerWidget {
  const _Player({required this.clockKey, required this.side, required this.upsideDown});

  final Side side;

  final Key clockKey;

  final bool upsideDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(overTheBoardGameControllerProvider);
    final boardPreferences = ref.watch(boardPreferencesProvider);
    final clock = ref.watch(overTheBoardClockProvider);

    return RotatedBox(
      quarterTurns: upsideDown ? 2 : 0,
      child: GamePlayer(
        game: gameState.game,
        side: side,
        materialDiff:
            boardPreferences.materialDifferenceFormat.visible
                ? gameState.currentMaterialDiff(side)
                : null,
        materialDifferenceFormat: boardPreferences.materialDifferenceFormat,
        shouldLinkToUserProfile: false,
        clock:
            clock.timeIncrement.isInfinite
                ? null
                : Clock(
                  timeLeft: Duration(milliseconds: max(0, clock.timeLeft(side)!.inMilliseconds)),
                  key: clockKey,
                  active: clock.activeClock == side,
                  // https://github.com/lichess-org/mobile/issues/785#issuecomment-2183903498
                  emergencyThreshold: Duration(
                    seconds: (clock.timeIncrement.time * 0.125).clamp(10, 60).toInt(),
                  ),
                ),
      ),
    );
  }
}
