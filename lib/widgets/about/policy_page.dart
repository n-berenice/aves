import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/basic/markdown_container.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/behaviour/intents.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PolicyPage extends StatefulWidget {
  static const routeName = '/about/policy';

  const PolicyPage({super.key});

  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  late Future<String> _termsLoader;
  final ScrollController _scrollController = ScrollController();

  static const termsPath = 'assets/terms.md';
  static const termsDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _termsLoader = rootBundle.loadString(termsPath);
  }

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !settings.useTvLayout,
        title: Text(context.l10n.policyPageTitle),
      ),
      body: SafeArea(
        child: FocusableActionDetector(
          autofocus: true,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowUp): VerticalScrollIntent.up(),
            SingleActivator(LogicalKeyboardKey.arrowDown): VerticalScrollIntent.down(),
          },
          actions: {
            VerticalScrollIntent: VerticalScrollIntentAction(scrollController: _scrollController),
          },
          child: Center(
            child: FutureBuilder<String>(
              future: _termsLoader,
              builder: (context, snapshot) {
                if (snapshot.hasError || snapshot.connectionState != ConnectionState.done) return const SizedBox();
                final terms = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: MarkdownContainer(
                    scrollController: _scrollController,
                    data: terms,
                    textDirection: termsDirection,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
