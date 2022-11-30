import 'package:aves/model/actions/entry_actions.dart';
import 'package:aves/model/filters/album.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/widgets/common/app_bar/quick_choosers/album_chooser.dart';
import 'package:aves/widgets/common/app_bar/quick_choosers/chooser_button.dart';
import 'package:aves/widgets/common/providers/media_query_data_provider.dart';
import 'package:aves/widgets/filter_grids/common/filter_nav_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MoveButton extends ChooserQuickButton<String> {
  final bool copy;

  const MoveButton({
    super.key,
    required this.copy,
    super.chooserPosition,
    super.onChooserValue,
    required super.onPressed,
  });

  @override
  State<MoveButton> createState() => _MoveQuickButtonState();
}

class _MoveQuickButtonState extends ChooserQuickButtonState<MoveButton, String> {
  EntryAction get action => widget.copy ? EntryAction.copy : EntryAction.move;

  @override
  Widget get icon => action.getIcon();

  @override
  String get tooltip => action.getText(context);

  @override
  String? get defaultValue => null;

  @override
  Widget buildChooser(Animation<double> animation) {
    final options = settings.moveDestinationAlbums;
    final takeCount = Settings.moveDestinationAlbumMax - options.length;
    if (takeCount > 0) {
      final source = context.read<CollectionSource>();
      final filters = source.rawAlbums.whereNot(options.contains).map((album) => AlbumFilter(album, null)).toSet();
      final allMapEntries = filters.map((filter) => FilterGridItem(filter, source.recentEntry(filter))).toList();
      allMapEntries.sort(FilterNavigationPage.compareFiltersByDate);
      options.addAll(allMapEntries.take(takeCount).map((v) => v.filter.album));
    }

    return MediaQueryDataProvider(
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation,
          child: AlbumQuickChooser(
            valueNotifier: chooserValueNotifier,
            pointerGlobalPosition: pointerGlobalPosition,
            options: widget.chooserPosition == PopupMenuPosition.over ? options.reversed.toList() : options,
          ),
        ),
      ),
    );
  }
}
