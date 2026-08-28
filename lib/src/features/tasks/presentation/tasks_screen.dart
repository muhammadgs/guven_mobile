import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../auth/application/session_controller.dart';
import '../application/tasks_controller.dart';
import '../domain/task_item.dart';
import '../domain/task_scope.dart';
import '../domain/task_status.dart';
import 'widgets/task_card.dart';
import 'widgets/task_glass.dart';
import 'widgets/task_scope_bar.dart';
import 'widgets/task_tools.dart';

/// Tapşırıqlar — the task list.
///
/// The site shows this as a table; on a phone it is a list of cards, one per
/// row of that table, each one carrying the columns that fit and opening to
/// show the rest. Above them sit the five scopes and the two tool buttons.
///
/// Nothing here scrolls except the list: the title, the scope bar and the
/// tools are the fixed frame, exactly as the home screen's greeting and counts
/// are.
class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.bottomReserve,
    required this.active,
  });

  /// Vertical space the floating nav bar occupies, which this screen must keep
  /// clear at the bottom of its list.
  final double bottomReserve;

  /// Whether this is the tab on screen.
  ///
  /// The shell keeps every visited tab alive in an `IndexedStack`, which builds
  /// all five of them at sign-in. Without this the task list would fire its
  /// request on launch, for a screen nobody has opened.
  final bool active;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TasksController? _controller;

  /// A one-line failure notice shown above the list for a few seconds.
  ///
  /// The app has no `Scaffold` anywhere — the shell owns the background and
  /// the nav bar itself — so there is no `ScaffoldMessenger` for a `SnackBar`
  /// to land in, and the screen carries its own.
  String? _flash;
  Timer? _flashTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= TasksController(SessionScope.read(context));
    if (widget.active) _loadOnce();
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadOnce();
  }

  /// The first visit loads; later ones keep what is already there, and a pull
  /// is what goes back to the network.
  void _loadOnce() {
    final TasksController tasks = _controller!;
    if (tasks.current.loaded || tasks.current.loading) return;
    tasks.load();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _showFlash(String message) {
    _flashTimer?.cancel();
    setState(() => _flash = message);
    _flashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _run(TaskAction action, TaskItem task) async {
    final String? failure = await _controller!.run(action, task);
    if (failure != null && mounted) _showFlash(failure);
  }

  @override
  Widget build(BuildContext context) {
    final TasksController tasks = _controller!;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return ListenableBuilder(
      listenable: tasks,
      builder: (BuildContext context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            scaled(context, 22),
            safe.top + scaled(context, 10),
            scaled(context, 22),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Title(),
              SizedBox(height: scaled(context, 18)),
              TaskScopeBar(
                scopes: TaskScope.values,
                selected: tasks.scope,
                onSelected: tasks.select,
                height: scaled(context, 40),
                iconSize: scaled(context, 15),
                textStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: scaled(context, 12.5),
                  height: 1.1,
                ),
              ),
              SizedBox(height: scaled(context, 14)),
              Align(
                alignment: Alignment.centerLeft,
                child: TaskToolButtons(
                  size: scaled(context, 42),
                  gap: scaled(context, 12),
                  onFilter: () => _showFlash('Filtr bölməsi hazırlanır.'),
                  onCreate: () =>
                      _showFlash('Yeni tapşırıq bölməsi hazırlanır.'),
                ),
              ),
              _FlashBar(message: _flash),
              SizedBox(height: scaled(context, 14)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: tasks.load,
                  edgeOffset: scaled(context, 8),
                  color: kGlassInk,
                  backgroundColor: const Color(0xE6FFFFFF),
                  child: _TaskList(
                    controller: tasks,
                    bottomReserve: widget.bottomReserve,
                    onAction: _run,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Tapşırıqlar',
        maxLines: 1,
        style: TextStyle(
          color: kGlassInk,
          // CalSans, the same display face as the home screen's greeting —
          // these two are the app's page titles and read as a pair.
          fontFamily: 'CalSans',
          fontSize: responsive(context, factor: 0.092, min: 30, max: 42),
          height: 1.08,
          letterSpacing: -1.0,
        ),
      ),
    );
  }
}

/// The failure notice. Takes no vertical room at all when there is nothing to
/// say, so the list does not shift when one appears.
class _FlashBar extends StatelessWidget {
  const _FlashBar({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: scaled(context, 12)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scaled(context, 14),
                  vertical: scaled(context, 9),
                ),
                decoration: ShapeDecoration(
                  color: const Color(0xF0FFFFFF),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(scaled(context, 14)),
                  ),
                  shadows: kTaskCardLift,
                ),
                child: Text(
                  message!,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: scaled(context, 13),
                    height: 1.3,
                    color: kGlassInk,
                  ),
                ),
              ),
            ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.controller,
    required this.bottomReserve,
    required this.onAction,
  });

  final TasksController controller;
  final double bottomReserve;
  final Future<void> Function(TaskAction, TaskItem) onAction;

  @override
  Widget build(BuildContext context) {
    final TaskScopeState state = controller.current;
    final EdgeInsets padding = EdgeInsets.only(bottom: bottomReserve);

    if (state.loading && !state.loaded) {
      return _Message(
        padding: padding,
        child: const CircularProgressIndicator(
          strokeWidth: 2.4,
          color: kGlassInk,
        ),
      );
    }

    if (state.error != null && state.tasks.isEmpty) {
      return _Message(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: scaled(context, 14),
                height: 1.35,
                color: kGlassInkMuted,
              ),
            ),
            SizedBox(height: scaled(context, 10)),
            TextButton(
              onPressed: controller.load,
              child: const Text('Yenidən cəhd et'),
            ),
          ],
        ),
      );
    }

    if (state.tasks.isEmpty) {
      return _Message(
        padding: padding,
        child: Text(
          controller.scope.emptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: scaled(context, 14),
            height: 1.35,
            color: kGlassInkMuted,
          ),
        ),
      );
    }

    // One backdrop group for the whole list: every card's blur samples the
    // same snapshot of what is behind it, which is one filter pass per frame
    // instead of one per card.
    return BackdropGroup(
      child: ListView.separated(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.tasks.length,
        separatorBuilder: (BuildContext context, _) =>
            SizedBox(height: scaled(context, 14)),
        itemBuilder: (BuildContext context, int index) {
          final TaskItem task = state.tasks[index];
          return TaskCard(
            key: ValueKey<Object>(task.id ?? index),
            task: task,
            mine: task.isMine(
              userId: controller.myUserId,
              fullName: controller.myFullName,
            ),
            busy: controller.isBusy(task),
            attachments: controller.attachmentsOf(task),
            onAction: (TaskAction action) => onAction(action, task),
            onOpened: () => controller.loadAttachments(task),
          );
        },
      ),
    );
  }
}

/// A centred message that still scrolls, so pull-to-refresh works on an empty
/// or failed list too.
class _Message extends StatelessWidget {
  const _Message({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          padding: padding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: constraints.maxHeight * 0.6,
              child: Center(child: child),
            ),
          ],
        );
      },
    );
  }
}
