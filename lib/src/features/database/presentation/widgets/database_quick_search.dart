import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/database_filter_source.dart';
import '../database_filter_metrics.dart';
import 'database_filter_panel.dart' show DatabaseMagnifierPainter;
import 'database_glass.dart';

/// How long typing has to pause before the list is asked again: one request
/// for a word, not one a letter.
const Duration kQuickSearchPause = Duration(milliseconds: 400);

/// The quick search bar beside the funnel (2026-11-08): a capsule of the
/// buttons' own liquid glass, the filter's magnifier, and the page's headline
/// as its hint — `Müştəri` on `Satışlar`.
///
/// What is typed narrows the list to the rows whose headline holds it, found
/// in the whole of the 1C table the way the filter finds a value — see
/// [DatabaseQuickSearchSource]. It asks once typing pauses, at once on the
/// keyboard's search key, and lets go at once when cleared.
///
/// It is as tall as the buttons beside it and takes the rest of the row, so
/// on every phone its right edge is the titles' right margin.
class DatabaseQuickSearchBar extends StatefulWidget {
  const DatabaseQuickSearchBar({
    super.key,
    required this.source,
    required this.height,
  });

  final DatabaseQuickSearchSource source;

  /// The buttons' side.
  final double height;

  @override
  State<DatabaseQuickSearchBar> createState() => _DatabaseQuickSearchBarState();
}

class _DatabaseQuickSearchBarState extends State<DatabaseQuickSearchBar> {
  late final TextEditingController _text = TextEditingController(
    text: widget.source.quickSearch,
  );
  final FocusNode _focus = FocusNode();
  Timer? _pause;

  @override
  void didUpdateWidget(covariant DatabaseQuickSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _pause?.cancel();
      _text.text = widget.source.quickSearch;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _pause?.cancel();
    if (text.trim().isEmpty) {
      _ask(text);
      return;
    }
    _pause = Timer(kQuickSearchPause, () => _ask(text));
  }

  void _ask(String text) {
    _pause?.cancel();
    if (!mounted) return;
    widget.source.setQuickSearch(text);
  }

  void _clear() {
    _text.clear();
    _ask('');
  }

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final double height = widget.height;
    final double radius = height / 2;
    // The filter's own search field, to the stroke: its magnifier is drawn
    // for that field's side, so it is handed the same side here.
    final double side = DatabaseFilterMetrics.kControlSize * s;
    final TextStyle style = TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w400,
      fontSize: DatabaseFilterMetrics.kLabelSize * s,
      height: 1.2,
      letterSpacing: 0,
      color: kGlassInk,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: kGlassLift,
        ),
        child: SizedBox(
          height: height,
          child: AppGlassSurface(
            // The buttons' glass beside it, rim and all — see
            // [GlassToolButton].
            backend: AppGlassBackend.easy,
            style: glassAtRadius(kTaskToolGlass, radius),
            cornerRadius: radius,
            child: Row(
              children: <Widget>[
                SizedBox(width: height * 0.3),
                CustomPaint(
                  painter: DatabaseMagnifierPainter(side),
                  size: Size.square(side * 0.48),
                ),
                SizedBox(width: side * 0.22),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    style: style,
                    cursorColor: kGlassInk,
                    cursorWidth: 1.6,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    onChanged: _onChanged,
                    onSubmitted: (String text) {
                      _ask(text);
                      _focus.unfocus();
                    },
                    onTapOutside: (_) => _focus.unfocus(),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.source.quickSearchHint,
                      hintStyle: style.copyWith(color: kGlassInkMuted),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: _text,
                  builder: (BuildContext context, _) {
                    if (_text.text.isEmpty) {
                      return SizedBox(width: height * 0.3);
                    }
                    return Semantics(
                      button: true,
                      label: 'Axtarışı təmizlə',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _clear,
                        child: SizedBox.square(
                          dimension: height,
                          child: Icon(
                            Icons.close_rounded,
                            size: side * 0.45,
                            color: kGlassInkMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
