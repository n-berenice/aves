import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/widgets/about/about_page.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/search/page.dart';
import 'package:aves/widgets/common/search/route.dart';
import 'package:aves/widgets/debug/app_debug_page.dart';
import 'package:aves/widgets/filter_grids/albums_page.dart';
import 'package:aves/widgets/filter_grids/countries_page.dart';
import 'package:aves/widgets/filter_grids/tags_page.dart';
import 'package:aves/widgets/navigation/drawer/tile.dart';
import 'package:aves/widgets/search/search_delegate.dart';
import 'package:aves/widgets/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PageNavTile extends StatelessWidget {
  final Widget? trailing;
  final bool topLevel;
  final String routeName;

  const PageNavTile({
    super.key,
    this.trailing,
    this.topLevel = true,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ListTile(
        // key is expected by test driver
        key: Key('$routeName-tile'),
        leading: DrawerPageIcon(route: routeName),
        title: DrawerPageTitle(route: routeName),
        trailing: trailing != null
            ? Builder(
                builder: (context) => DefaultTextStyle.merge(
                  style: TextStyle(
                    color: IconTheme.of(context).color!.withOpacity(.6),
                  ),
                  child: trailing!,
                ),
              )
            : null,
        onTap: () {
          Navigator.maybeOf(context)?.pop();
          final route = routeBuilder(context, routeName);
          if (topLevel) {
            Navigator.maybeOf(context)?.pushAndRemoveUntil(
              route,
              (route) => false,
            );
          } else {
            Navigator.maybeOf(context)?.push(route);
          }
        },
        selected: context.currentRouteName == routeName,
      ),
    );
  }

  static Route routeBuilder(BuildContext context, String routeName) {
    switch (routeName) {
      case SearchPage.routeName:
        final currentCollection = context.read<CollectionLens?>();
        return SearchPageRoute(
          delegate: CollectionSearchDelegate(
            searchFieldLabel: context.l10n.searchCollectionFieldHint,
            source: context.read<CollectionSource>(),
            parentCollection: currentCollection?.copyWith(),
          ),
        );
      default:
        return MaterialPageRoute(
          settings: RouteSettings(name: routeName),
          builder: _materialPageBuilder(routeName),
        );
    }
  }

  static WidgetBuilder _materialPageBuilder(String routeName) {
    switch (routeName) {
      case AlbumListPage.routeName:
        return (_) => const AlbumListPage();
      case CountryListPage.routeName:
        return (_) => const CountryListPage();
      case TagListPage.routeName:
        return (_) => const TagListPage();
      case SettingsPage.routeName:
        return (_) => const SettingsPage();
      case AboutPage.routeName:
        return (_) => const AboutPage();
      case AppDebugPage.routeName:
        return (_) => const AppDebugPage();
      default:
        throw Exception('unknown route=$routeName');
    }
  }
}
