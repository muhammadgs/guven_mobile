import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../application/database_list_controller.dart';
import '../database_format.dart';
import 'database_glass.dart';

/// How far ahead of the reader the next page is asked for, in screens.
///
/// A page is four or five screens of cards. Asking once the reader is within
/// two of the end gives the answer most of a page's reading to arrive in, so
/// only a hard fling ever reaches the bottom first — and even then it finds
/// a spinner, not an end.
const double kDatabasePrefetchScreens = 2;

/// The gap between two cards on the design's frame: `Satışlar`' and
/// `Stok`'s designs, and the lists drawn after them.
const double kDatabaseCardGap = 11.5;

/// What a list calls its rows, in the sentences it says about them.
@immutable
class DatabaseListWords {
  const DatabaseListWords({
    required this.unit,
    required this.checking,
    required this.empty,
    required this.filteredEmpty,
  });

  /// One row, counted: `12 sənəd`, `4 / 799 qeyd yoxlanıldı`.
  final String unit;

  /// What a filter says while it is still reading, before it knows how many
  /// rows there are to read: `Sənədlər yoxlanılır…`.
  final String checking;

  /// The list with nothing in it: `Satış sənədi tapılmadı.`
  final String empty;

  /// A filter that let nothing through.
  final String filteredEmpty;
}

/// Builds the card for [row], which sits in [rows] — the whole list, or the
/// filtered one laid over it.
typedef DatabaseCardBuilder<T> =
    Widget Function(BuildContext context, DatabaseRows<T> rows, T row);

/// A `Baza` page's cards, fetched a page at a time as the list is scrolled
/// towards its end — or, while a filter is on, the rows it lets through.
///
/// The two are two lists, and both stay built: the filtered one is laid over
/// the other rather than replacing it, so letting go of the filter shows the
/// list exactly as it was left — the same cards open, scrolled to the same
/// place.
///
/// Only the cards on screen, and a little either side, exist at any moment:
/// each list is built lazily, so it costs the same to scroll with twenty rows
/// loaded as with eight thousand. Every card's blur samples one shared
/// snapshot of the background ([BackdropGroup]) — one blur per frame for the
/// whole list, not one per card.
class DatabaseList<T> extends StatefulWidget {
  const DatabaseList({
    super.key,
    required this.source,
    required this.bottomReserve,
    required this.sideInset,
    required this.keyOf,
    required this.card,
    required this.words,
    this.gap = kDatabaseCardGap,
  });

  final DatabaseListSource<T> source;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's. The cards are wider than the titles
  /// above them, as the designs draw them.
  final double sideInset;

  /// What keeps a card's state with its row as rows arrive above it.
  final Object Function(T row) keyOf;

  final DatabaseCardBuilder<T> card;
  final DatabaseListWords words;

  /// Between one card and the next, on the design's frame.
  final double gap;

  @override
  State<DatabaseList<T>> createState() => _DatabaseListState<T>();
}

class _DatabaseListState<T> extends State<DatabaseList<T>> {
  // Starts where the list was left: leaving the page for another and coming
  // back should not lose the reader's place.
  late final ScrollController _base = ScrollController(
    initialScrollOffset: widget.source.scrollOffset,
  )..addListener(_maybeLoadMore);

  /// The filtered list's, new for every new filter: a different question
  /// starts at the top.
  ScrollController? _filtered;
  int? _filteredSerial;

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_afterChange);
    _loadAfterFrame();
  }

  @override
  void didUpdateWidget(covariant DatabaseList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source == widget.source) return;
    oldWidget.source.removeListener(_afterChange);
    widget.source.addListener(_afterChange);
    _loadAfterFrame();
  }

  /// Page one, once this frame is built. Starting it announces the load at
  /// once, and the funnel above the list — built earlier in this same frame
  /// — listens to the same source.
  void _loadAfterFrame() {
    final DatabaseListSource<T> source = widget.source;
    WidgetsBinding.instance.addPostFrameCallback((_) => source.ensureLoaded());
  }

  @override
  void dispose() {
    if (_base.hasClients) widget.source.scrollOffset = _base.offset;
    widget.source.removeListener(_afterChange);
    _base.dispose();
    _filtered?.dispose();
    super.dispose();
  }

  /// The list on screen.
  DatabaseRows<T> get _rows => widget.source.filtered ?? widget.source;

  /// A page that has just landed may still leave the list too short to
  /// scroll — a tablet, a page that was mostly rows already shown, a filter
  /// that has matched little so far — and a list that cannot scroll never
  /// asks for more on its own. So look again once it has been laid out.
  void _afterChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });
  }

  void _maybeLoadMore() {
    final DatabaseRows<T> rows = _rows;
    final ScrollController? scroll = rows is DatabaseFilteredRows<T>
        ? _filtered
        : _base;
    if (scroll == null || !scroll.hasClients) {
      // A filter that has found nothing yet shows a message, not a list,
      // and a message cannot be scrolled towards its end.
      if (rows is DatabaseFilteredRows<T> && rows.rows.isEmpty) {
        rows.loadMore();
      }
      return;
    }
    final ScrollPosition position = scroll.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter <
        position.viewportDimension * kDatabasePrefetchScreens) {
      // A no-op unless a page is actually due.
      rows.loadMore();
    }
  }

  /// The filtered list's scroll controller, made new for a new filter. The
  /// old one is let go after the frame, once its list has.
  ScrollController? _scrollFor(DatabaseFilteredRows<T>? view) {
    if (view?.serial == _filteredSerial) return _filtered;
    final ScrollController? old = _filtered;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _filteredSerial = view?.serial;
    _filtered = view == null
        ? null
        : (ScrollController()..addListener(_maybeLoadMore));
    return _filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.source,
      builder: (BuildContext context, _) {
        final DatabaseListSource<T> source = widget.source;
        final DatabaseFilteredRows<T>? view = source.filtered;
        final ScrollController? filtered = _scrollFor(view);
        final EdgeInsets padding = EdgeInsets.fromLTRB(
          widget.sideInset,
          0,
          widget.sideInset,
          widget.bottomReserve,
        );

        return IndexedStack(
          index: view == null ? 0 : 1,
          sizing: StackFit.expand,
          children: <Widget>[
            _list(context, source, _base, padding),
            if (view == null)
              const SizedBox.shrink()
            else
              KeyedSubtree(
                key: ValueKey<int>(view.serial),
                child: _list(context, view, filtered!, padding),
              ),
          ],
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    DatabaseRows<T> rows,
    ScrollController scroll,
    EdgeInsets padding,
  ) {
    return RefreshIndicator(
      onRefresh: rows.refresh,
      edgeOffset: scaled(context, 8),
      color: kGlassInk,
      backgroundColor: const Color(0xE6FFFFFF),
      // No stretch at the ends: Android's stretch draws the list into a
      // layer of its own, and a blur inside one has nothing behind it to
      // sample — every card would lose its blur for as long as the list was
      // pulled.
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
        child: rows.rows.isEmpty
            ? _Message(padding: padding, rows: rows, words: widget.words)
            : _cards(context, rows, scroll, padding),
      ),
    );
  }

  Widget _cards(
    BuildContext context,
    DatabaseRows<T> rows,
    ScrollController scroll,
    EdgeInsets padding,
  ) {
    final double s = databaseScale(context);
    final String? error = rows.error;
    // A pull that failed leaves the old cards where they were, under a line
    // saying so.
    final int lead = error == null ? 0 : 1;
    final List<T> list = rows.rows;

    return BackdropGroup(
      child: ListView.builder(
        controller: scroll,
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: lead + list.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index < lead) {
            return Padding(
              padding: EdgeInsets.only(bottom: 11.5 * s),
              child: _Notice(message: error!, onRetry: rows.refresh),
            );
          }
          final int at = index - lead;
          if (at == list.length) {
            return _Footer(rows: rows, words: widget.words);
          }

          final T row = list[at];
          return KeyedSubtree(
            key: ValueKey<Object>(widget.keyOf(row)),
            child: Padding(
              padding: EdgeInsets.only(top: at == 0 ? 0 : widget.gap * s),
              child: widget.card(context, rows, row),
            ),
          );
        },
      ),
    );
  }
}

/// Under the last card: a spinner while there is more to come, a way to ask
/// again if the last page failed, and nothing once there is no more — or,
/// under a filter, how many it found.
class _Footer extends StatelessWidget {
  const _Footer({required this.rows, required this.words});

  final DatabaseRows<Object?> rows;
  final DatabaseListWords words;

  @override
  Widget build(BuildContext context) {
    final DatabaseRows<Object?> rows = this.rows;
    final double s = databaseScale(context);
    final String? error = rows.moreError;

    if (error != null) {
      return Padding(
        padding: EdgeInsets.only(top: 11.5 * s),
        child: _Notice(message: error, onRetry: rows.retryMore),
      );
    }
    if (!rows.hasMore) {
      if (rows is! DatabaseFilteredRows<Object?>) {
        return const SizedBox.shrink();
      }
      // Every row the filter lets through is on screen: say how many, so a
      // short list reads as the whole answer and not a slow one.
      return SizedBox(
        height: 56 * s,
        child: Center(
          child: Text(
            '${formatCount(rows.rows.length)} ${words.unit}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5 * s,
              height: 1.2,
              color: kGlassInkMuted,
            ),
          ),
        ),
      );
    }

    // Shown whenever more is coming, not only while it is being fetched: by
    // the time anybody scrolls this far the request is already out, and a
    // spinner says so where a blank would say "the end".
    return SizedBox(
      height: 64 * s,
      child: Center(
        child: _Searching(rows: rows, words: words),
      ),
    );
  }
}

/// A spinner — and, while a filter is reading rows one by one, how far
/// through them it is.
class _Searching extends StatelessWidget {
  const _Searching({required this.rows, required this.words});

  final DatabaseRows<Object?> rows;
  final DatabaseListWords words;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final Widget spinner = SizedBox.square(
      dimension: 20 * s,
      child: const CircularProgressIndicator(
        strokeWidth: 2.2,
        color: kGlassInk,
      ),
    );
    final DatabaseRows<Object?> rows = this.rows;
    if (rows is! DatabaseFilteredRows<Object?> || !rows.scans) return spinner;

    final int? of = rows.readOf;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        spinner,
        SizedBox(height: 8 * s),
        Text(
          of == null
              ? words.checking
              : '${formatCount(rows.read)} / ${formatCount(of)} '
                    '${words.unit} yoxlanıldı',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5 * s,
            height: 1.2,
            color: kGlassInkMuted,
          ),
        ),
      ],
    );
  }
}

/// A failed request, and a way to make it again. The same white capsule
/// `Əsas panel` says it with.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        scaled(context, 16),
        scaled(context, 6),
        scaled(context, 6),
        scaled(context, 6),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xF0FFFFFF),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(scaled(context, 16)),
        ),
        shadows: kGlassLift,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: scaled(context, 13),
                height: 1.3,
                color: kGlassInk,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Yenidən cəhd et')),
        ],
      ),
    );
  }
}

/// The list before it has a card to show: loading, failed, or empty. Still a
/// scrollable, so a pull works on it too.
class _Message extends StatelessWidget {
  const _Message({
    required this.padding,
    required this.rows,
    required this.words,
  });

  final EdgeInsets padding;
  final DatabaseRows<Object?> rows;
  final DatabaseListWords words;

  @override
  Widget build(BuildContext context) {
    final String? error = rows.error;
    final bool filtered = rows is DatabaseFilteredRows<Object?>;
    final TextStyle style = TextStyle(
      fontFamily: 'Poppins',
      fontSize: scaled(context, 14),
      height: 1.35,
      color: kGlassInkMuted,
    );

    final Widget child;
    if (!rows.hasLoaded || rows.isLoadingFirst) {
      child = filtered
          ? _Searching(rows: rows, words: words)
          : const CircularProgressIndicator(strokeWidth: 2.4, color: kGlassInk);
    } else if (error != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(error, textAlign: TextAlign.center, style: style),
          SizedBox(height: scaled(context, 10)),
          TextButton(
            onPressed: rows.refresh,
            child: const Text('Yenidən cəhd et'),
          ),
        ],
      );
    } else if (rows.moreError != null) {
      child = _Notice(message: rows.moreError!, onRetry: rows.retryMore);
    } else if (rows.hasMore) {
      // A filter still reading: nothing found yet is not nothing found.
      child = _Searching(rows: rows, words: words);
    } else {
      child = Text(
        filtered ? words.filteredEmpty : words.empty,
        textAlign: TextAlign.center,
        style: style,
      );
    }

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
