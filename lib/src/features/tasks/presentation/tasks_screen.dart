import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../auth/application/session_controller.dart';
import '../application/task_edit_controller.dart';
import '../application/tasks_controller.dart';
import '../domain/new_task.dart';
import '../domain/task_attachment.dart';
import '../domain/task_item.dart';
import '../domain/task_scope.dart';
import '../domain/task_status.dart';
import 'widgets/new_task_panel.dart';
import 'widgets/task_card.dart';
import 'widgets/task_edit_panel.dart';
import 'widgets/task_filter_panel.dart';
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

  /// True while the filter panel is up. The funnel button steps aside for
  /// it, because the panel is that button's own glass.
  bool _filterOpen = false;

  /// True while the `Yeni tapşırıq` chooser or form is up, for the same
  /// reason: that surface *is* the `+` button's glass.
  bool _createOpen = false;

  /// The task whose `Redaktə` sheet is up, so that card's own button steps
  /// aside for it. By id rather than by row: a refresh landing while the sheet
  /// is open replaces the row object.
  int? _editingId;

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

  Future<void> _run(TaskAction action, TaskItem task, Rect button) async {
    if (action == TaskAction.edit) return _openEdit(task, button);
    final String? failure = await _controller!.run(action, task);
    if (failure != null && mounted) _showFlash(failure);
  }

  /// Opens `Redaktə`, growing out of the button that was pressed.
  ///
  /// The card is refetched afterwards whatever the sheet changed: it may have
  /// handed the task to somebody else, in which case this row belongs to a
  /// different person now and possibly to a different cell.
  Future<void> _openEdit(TaskItem task, Rect button) async {
    setState(() => _editingId = task.id);
    final TaskEditOutcome? saved = await openTaskEdit(
      context,
      button: button,
      radius: button.height / 2,
      session: SessionScope.read(context),
      task: task,
    );
    if (!mounted) return;
    setState(() => _editingId = null);
    if (saved == null) return;

    _controller!.applyEdit(task, status: saved.status);
    _showFlash(saved.message ?? 'Tapşırıq yeniləndi.');
  }

  /// Opens the filter, growing out of the button that was pressed.
  Future<void> _openFilter(Rect button, double radius) async {
    setState(() => _filterOpen = true);
    await openTaskFilter(
      context,
      button: button,
      radius: radius,
      controller: _controller!,
    );
    if (mounted) setState(() => _filterOpen = false);
  }

  /// Opens `Yeni tapşırıq`, growing out of the `+` that was pressed.
  ///
  /// A task that was actually created switches the scope bar to the cell it
  /// landed in and reloads that cell — the three kinds live in three different
  /// resources, so a new `Şirkət` task would otherwise be invisible from
  /// `Daxili`, where it was raised.
  Future<void> _openCreate(Rect button, double radius) async {
    setState(() => _createOpen = true);
    final NewTaskKind? created = await openNewTask(
      context,
      button: button,
      radius: radius,
      session: SessionScope.read(context),
    );
    if (!mounted) return;
    setState(() => _createOpen = false);
    if (created == null) return;

    final TasksController tasks = _controller!;
    tasks.select(created.scope);
    unawaited(tasks.load(created.scope));
    _showFlash('Tapşırıq yaradıldı.');
  }

  Future<void> _openFile(TaskAttachment file) async {
    final String? failure = await _controller!.openAttachment(file);
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
                  filterCount: tasks.filter.activeFieldCount,
                  filterHidden: _filterOpen,
                  createHidden: _createOpen,
                  onFilter: _openFilter,
                  onCreate: _openCreate,
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
                    editingId: _editingId,
                    onAction: _run,
                    onOpenFile: _openFile,
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
    required this.editingId,
    required this.onAction,
    required this.onOpenFile,
  });

  final TasksController controller;
  final double bottomReserve;

  /// The task whose edit sheet is up, or null.
  final int? editingId;

  final Future<void> Function(TaskAction, TaskItem, Rect) onAction;
  final ValueChanged<TaskAttachment> onOpenFile;

  @override
  Widget build(BuildContext context) {
    final TaskScopeState state = controller.current;
    final EdgeInsets padding = EdgeInsets.only(bottom: bottomReserve);

    // Hesabat is deliberately blank until its own design lands: it fetches
    // nothing, so there is nothing to say about it either.
    if (!controller.scope.hasFeed) return const SizedBox.expand();

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

    // What the filter left behind, which is the whole list when nothing is
    // selected.
    final List<TaskItem> tasks = state.visible;

    if (tasks.isEmpty) {
      // An empty list and a list filtered down to nothing are different
      // things, and saying "no tasks" for the second would be a lie about
      // the data — with the way out of it hidden behind a button the user has
      // no reason to press again.
      final bool filtered = state.tasks.isNotEmpty;
      return _Message(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              filtered
                  ? 'Filtrə uyğun tapşırıq yoxdur.'
                  : controller.scope.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: scaled(context, 14),
                height: 1.35,
                color: kGlassInkMuted,
              ),
            ),
            if (filtered)
              TextButton(
                onPressed: controller.clearFilter,
                child: const Text('Filtri sıfırla'),
              ),
          ],
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
        itemCount: tasks.length,
        separatorBuilder: (BuildContext context, _) =>
            SizedBox(height: scaled(context, 14)),
        itemBuilder: (BuildContext context, int index) {
          final TaskItem task = tasks[index];
          return TaskCard(
            key: ValueKey<Object>(task.id ?? index),
            task: task,
            mine: task.isMine(
              userId: controller.myUserId,
              fullName: controller.myFullName,
            ),
            // `Redaktə` belongs to two people: the executor and whoever raised
            // the task. Nobody else gets the button at all.
            canEdit: task.canEdit(
              userId: controller.myUserId,
              fullName: controller.myFullName,
            ),
            editing: task.id != null && task.id == editingId,
            busy: controller.isBusy(task),
            attachments: controller.attachmentsOf(task),
            openingFileIds: controller.openingFileIds,
            voice: controller.voice,
            onAction: (TaskAction action, Rect button) =>
                onAction(action, task, button),
            onOpenFile: onOpenFile,
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
