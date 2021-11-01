import 'dart:async';

import 'package:aves/app_mode.dart';
import 'package:aves/model/actions/entry_set_actions.dart';
import 'package:aves/model/entry.dart';
import 'package:aves/model/selection.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/enums.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/collection/entry_set_action_delegate.dart';
import 'package:aves/widgets/collection/filter_bar.dart';
import 'package:aves/widgets/common/app_bar_subtitle.dart';
import 'package:aves/widgets/common/app_bar_title.dart';
import 'package:aves/widgets/common/basic/menu.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/dialogs/aves_selection_dialog.dart';
import 'package:aves/widgets/search/search_delegate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class CollectionAppBar extends StatefulWidget {
  final ValueNotifier<double> appBarHeightNotifier;
  final CollectionLens collection;

  const CollectionAppBar({
    Key? key,
    required this.appBarHeightNotifier,
    required this.collection,
  }) : super(key: key);

  @override
  _CollectionAppBarState createState() => _CollectionAppBarState();
}

class _CollectionAppBarState extends State<CollectionAppBar> with SingleTickerProviderStateMixin {
  final EntrySetActionDelegate _actionDelegate = EntrySetActionDelegate();
  late AnimationController _browseToSelectAnimation;
  late Future<bool> _canAddShortcutsLoader;
  final ValueNotifier<bool> _isSelectingNotifier = ValueNotifier(false);

  CollectionLens get collection => widget.collection;

  CollectionSource get source => collection.source;

  bool get hasFilters => collection.filters.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _browseToSelectAnimation = AnimationController(
      duration: context.read<DurationsData>().iconAnimation,
      vsync: this,
    );
    _isSelectingNotifier.addListener(_onActivityChange);
    _canAddShortcutsLoader = androidAppService.canPinToHomeScreen();
    _registerWidget(widget);
    WidgetsBinding.instance!.addPostFrameCallback((_) => _onFilterChanged());
  }

  @override
  void didUpdateWidget(covariant CollectionAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    _isSelectingNotifier.removeListener(_onActivityChange);
    _browseToSelectAnimation.dispose();
    super.dispose();
  }

  void _registerWidget(CollectionAppBar widget) {
    widget.collection.filterChangeNotifier.addListener(_onFilterChanged);
  }

  void _unregisterWidget(CollectionAppBar widget) {
    widget.collection.filterChangeNotifier.removeListener(_onFilterChanged);
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    return Selector<Selection<AvesEntry>, Tuple2<bool, int>>(
      selector: (context, selection) => Tuple2(selection.isSelecting, selection.selectedItems.length),
      builder: (context, s, child) {
        final isSelecting = s.item1;
        final selectedItemCount = s.item2;
        _isSelectingNotifier.value = isSelecting;
        return AnimatedBuilder(
          animation: collection.filterChangeNotifier,
          builder: (context, child) {
            final removableFilters = appMode != AppMode.pickInternal;
            return FutureBuilder<bool>(
              future: _canAddShortcutsLoader,
              builder: (context, snapshot) {
                final canAddShortcuts = snapshot.data ?? false;
                return SliverAppBar(
                  leading: appMode.hasDrawer ? _buildAppBarLeading(isSelecting) : null,
                  title: _buildAppBarTitle(isSelecting),
                  actions: _buildActions(
                    isSelecting: isSelecting,
                    selectedItemCount: selectedItemCount,
                    supportShortcuts: canAddShortcuts,
                  ),
                  bottom: hasFilters
                      ? FilterBar(
                          filters: collection.filters,
                          removable: removableFilters,
                          onTap: removableFilters ? collection.removeFilter : null,
                        )
                      : null,
                  titleSpacing: 0,
                  floating: true,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAppBarLeading(bool isSelecting) {
    VoidCallback? onPressed;
    String? tooltip;
    if (isSelecting) {
      onPressed = () => context.read<Selection<AvesEntry>>().browse();
      tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    } else {
      onPressed = Scaffold.of(context).openDrawer;
      tooltip = MaterialLocalizations.of(context).openAppDrawerTooltip;
    }
    return IconButton(
      // key is expected by test driver
      key: const Key('appbar-leading-button'),
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: _browseToSelectAnimation,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  Widget? _buildAppBarTitle(bool isSelecting) {
    final l10n = context.l10n;

    if (isSelecting) {
      return Selector<Selection<AvesEntry>, int>(
        selector: (context, selection) => selection.selectedItems.length,
        builder: (context, count, child) => Text(l10n.collectionSelectionPageTitle(count)),
      );
    } else {
      final appMode = context.watch<ValueNotifier<AppMode>>().value;
      Widget title = Text(appMode.isPicking ? l10n.collectionPickPageTitle : l10n.collectionPageTitle);
      if (appMode == AppMode.main) {
        title = SourceStateAwareAppBarTitle(
          title: title,
          source: source,
        );
      }
      return InteractiveAppBarTitle(
        onTap: appMode.canSearch ? _goToSearch : null,
        child: title,
      );
    }
  }

  List<Widget> _buildActions({
    required bool isSelecting,
    required int selectedItemCount,
    required bool supportShortcuts,
  }) {
    final appMode = context.watch<ValueNotifier<AppMode>>().value;
    bool isVisible(EntrySetAction action) => _actionDelegate.isVisible(
          action,
          appMode: appMode,
          isSelecting: isSelecting,
          supportShortcuts: supportShortcuts,
          sortFactor: collection.sortFactor,
          itemCount: collection.entryCount,
          selectedItemCount: selectedItemCount,
        );
    bool canApply(EntrySetAction action) => _actionDelegate.canApply(
          action,
          isSelecting: isSelecting,
          itemCount: collection.entryCount,
          selectedItemCount: selectedItemCount,
        );
    final canApplyEditActions = selectedItemCount > 0;

    final browsingQuickActions = settings.collectionBrowsingQuickActions;
    final selectionQuickActions = settings.collectionSelectionQuickActions;
    final quickActions = (isSelecting ? selectionQuickActions : browsingQuickActions).where(isVisible).map(
          (action) => _toActionButton(action, enabled: canApply(action)),
        );

    return [
      ...quickActions,
      MenuIconTheme(
        child: PopupMenuButton<EntrySetAction>(
          // key is expected by test driver
          key: const Key('appbar-menu-button'),
          itemBuilder: (context) {
            final generalMenuItems = EntrySetActions.general.where(isVisible).map(
                  (action) => _toMenuItem(action, enabled: canApply(action)),
                );

            final browsingMenuActions = EntrySetActions.browsing.where((v) => !browsingQuickActions.contains(v));
            final selectionMenuActions = EntrySetActions.selection.where((v) => !selectionQuickActions.contains(v));
            final contextualMenuItems = [
              ...(isSelecting ? selectionMenuActions : browsingMenuActions).where(isVisible).map(
                    (action) => _toMenuItem(action, enabled: canApply(action)),
                  ),
              if (isSelecting)
                PopupMenuItem<EntrySetAction>(
                  enabled: canApplyEditActions,
                  padding: EdgeInsets.zero,
                  child: PopupMenuItemExpansionPanel<EntrySetAction>(
                    enabled: canApplyEditActions,
                    icon: AIcons.edit,
                    title: context.l10n.collectionActionEdit,
                    items: [
                      _buildRotateAndFlipMenuItems(context, canApply: canApply),
                      ...[
                        EntrySetAction.editDate,
                        EntrySetAction.removeMetadata,
                      ].map((action) => _toMenuItem(action, enabled: canApply(action))),
                    ],
                  ),
                ),
            ];

            return [
              ...generalMenuItems,
              if (contextualMenuItems.isNotEmpty) ...[
                const PopupMenuDivider(),
                ...contextualMenuItems,
              ],
            ];
          },
          onSelected: (action) async {
            // wait for the popup menu to hide before proceeding with the action
            await Future.delayed(Durations.popupMenuAnimation * timeDilation);
            await _onCollectionActionSelected(action);
          },
        ),
      ),
    ];
  }

  // key is expected by test driver (e.g. 'menu-sort', 'menu-group', 'menu-map')
  Key _getActionKey(EntrySetAction action) => Key('menu-${action.toString().substring('EntrySetAction.'.length)}');

  Widget _toActionButton(EntrySetAction action, {bool enabled = true}) {
    return IconButton(
      key: _getActionKey(action),
      icon: action.getIcon(),
      onPressed: enabled ? () => _onCollectionActionSelected(action) : null,
      tooltip: action.getText(context),
    );
  }

  PopupMenuItem<EntrySetAction> _toMenuItem(EntrySetAction action, {bool enabled = true}) {
    return PopupMenuItem(
      key: _getActionKey(action),
      value: action,
      enabled: enabled,
      child: MenuRow(text: action.getText(context), icon: action.getIcon()),
    );
  }

  PopupMenuItem<EntrySetAction> _buildRotateAndFlipMenuItems(
    BuildContext context, {
    required bool Function(EntrySetAction action) canApply,
  }) {
    Widget buildDivider() => const SizedBox(
          height: 16,
          child: VerticalDivider(
            width: 1,
            thickness: 1,
          ),
        );

    Widget buildItem(EntrySetAction action) => Expanded(
          child: PopupMenuItem(
            value: action,
            enabled: canApply(action),
            child: Tooltip(
              message: action.getText(context),
              child: Center(child: action.getIcon()),
            ),
          ),
        );

    return PopupMenuItem(
      child: Row(
        children: [
          buildDivider(),
          buildItem(EntrySetAction.rotateCCW),
          buildDivider(),
          buildItem(EntrySetAction.rotateCW),
          buildDivider(),
          buildItem(EntrySetAction.flip),
          buildDivider(),
        ],
      ),
    );
  }

  void _onActivityChange() {
    if (context.read<Selection<AvesEntry>>().isSelecting) {
      _browseToSelectAnimation.forward();
    } else {
      _browseToSelectAnimation.reverse();
    }
  }

  void _onFilterChanged() {
    widget.appBarHeightNotifier.value = kToolbarHeight + (hasFilters ? FilterBar.preferredHeight : 0);

    if (hasFilters) {
      final filters = collection.filters;
      final selection = context.read<Selection<AvesEntry>>();
      if (selection.isSelecting) {
        final toRemove = selection.selectedItems.where((entry) => !filters.every((f) => f.test(entry))).toSet();
        selection.removeFromSelection(toRemove);
      }
    }
  }

  Future<void> _onCollectionActionSelected(EntrySetAction action) async {
    switch (action) {
      // general
      case EntrySetAction.sort:
        await _sort();
        break;
      case EntrySetAction.group:
        await _group();
        break;
      case EntrySetAction.select:
        context.read<Selection<AvesEntry>>().select();
        break;
      case EntrySetAction.selectAll:
        context.read<Selection<AvesEntry>>().addToSelection(collection.sortedEntries);
        break;
      case EntrySetAction.selectNone:
        context.read<Selection<AvesEntry>>().clearSelection();
        break;
      // browsing
      case EntrySetAction.search:
      case EntrySetAction.addShortcut:
      // browsing or selecting
      case EntrySetAction.map:
      case EntrySetAction.stats:
      // selecting
      case EntrySetAction.share:
      case EntrySetAction.delete:
      case EntrySetAction.copy:
      case EntrySetAction.move:
      case EntrySetAction.rescan:
      case EntrySetAction.rotateCCW:
      case EntrySetAction.rotateCW:
      case EntrySetAction.flip:
      case EntrySetAction.editDate:
      case EntrySetAction.removeMetadata:
        _actionDelegate.onActionSelected(context, action);
        break;
    }
  }

  Future<void> _sort() async {
    final value = await showDialog<EntrySortFactor>(
      context: context,
      builder: (context) => AvesSelectionDialog<EntrySortFactor>(
        initialValue: settings.collectionSortFactor,
        options: {
          EntrySortFactor.date: context.l10n.collectionSortDate,
          EntrySortFactor.size: context.l10n.collectionSortSize,
          EntrySortFactor.name: context.l10n.collectionSortName,
        },
        title: context.l10n.collectionSortTitle,
      ),
    );
    // wait for the dialog to hide as applying the change may block the UI
    await Future.delayed(Durations.dialogTransitionAnimation * timeDilation);
    if (value != null) {
      settings.collectionSortFactor = value;
    }
  }

  Future<void> _group() async {
    final value = await showDialog<EntryGroupFactor>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AvesSelectionDialog<EntryGroupFactor>(
          initialValue: settings.collectionSectionFactor,
          options: {
            EntryGroupFactor.album: l10n.collectionGroupAlbum,
            EntryGroupFactor.month: l10n.collectionGroupMonth,
            EntryGroupFactor.day: l10n.collectionGroupDay,
            EntryGroupFactor.none: l10n.collectionGroupNone,
          },
          title: l10n.collectionGroupTitle,
        );
      },
    );
    // wait for the dialog to hide as applying the change may block the UI
    await Future.delayed(Durations.dialogTransitionAnimation * timeDilation);
    if (value != null) {
      settings.collectionSectionFactor = value;
    }
  }

  void _goToSearch() {
    Navigator.push(
      context,
      SearchPageRoute(
        delegate: CollectionSearchDelegate(
          source: collection.source,
          parentCollection: collection,
        ),
      ),
    );
  }
}
