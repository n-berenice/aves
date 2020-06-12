import 'package:aves/model/settings.dart';
import 'package:aves/utils/durations.dart';
import 'package:aves/widgets/common/aves_logo.dart';
import 'package:aves/widgets/common/labeled_checkbox.dart';
import 'package:aves/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage();

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _hasAcceptedTerms = false;
  Future<String> _termsLoader;

  @override
  void initState() {
    super.initState();
    _termsLoader = rootBundle.loadString('assets/terms.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder(
              future: _termsLoader,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasError || snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
                final terms = snapshot.data;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _toStaggeredList(
                    duration: Durations.staggeredAnimation,
                    delay: Durations.staggeredAnimationDelay,
                    childAnimationBuilder: (child) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: child,
                      ),
                    ),
                    children: [
                      ..._buildTop(context),
                      Flexible(child: _buildTerms(terms)),
                      ..._buildBottomControls(context),
                    ],
                  ),
                );
              }),
        ),
      ),
    );
  }

  List<Widget> _buildTop(BuildContext context) {
    const message = Text(
      'Welcome to Aves',
      style: TextStyle(
        fontSize: 22,
        fontFamily: 'Concourse',
      ),
    );
    return [
      ...(MediaQuery.of(context).orientation == Orientation.portrait
          ? [
              const AvesLogo(size: 64),
              const SizedBox(height: 16),
              message,
            ]
          : [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AvesLogo(size: 48),
                  const SizedBox(width: 16),
                  message,
                ],
              )
            ]),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildBottomControls(BuildContext context) {
    final checkbox = LabeledCheckbox(
      value: _hasAcceptedTerms,
      onChanged: (v) => setState(() => _hasAcceptedTerms = v),
      text: 'I agree to the terms and conditions',
    );
    final button = RaisedButton(
      child: const Text('Continue'),
      onPressed: _hasAcceptedTerms
          ? () {
              settings.hasAcceptedTerms = true;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomePage(),
                ),
                (route) => false,
              );
            }
          : null,
    );
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? [
            checkbox,
            button,
          ]
        : [
            const SizedBox(height: 16),
            Row(
              children: [
                checkbox,
                const Spacer(),
                button,
              ],
            ),
          ];
  }

  Widget _buildTerms(String terms) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white10,
      ),
      constraints: const BoxConstraints(maxWidth: 460),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Markdown(
          data: terms,
          // TODO TLAD make it selectable when this fix (in 1.18.0-6.0.pre) lands on stable: https://github.com/flutter/flutter/pull/54479
          selectable: false,
          onTapLink: (url) async {
            if (await canLaunch(url)) {
              await launch(url);
            }
          },
          shrinkWrap: true,
        ),
      ),
    );
  }

  // workaround to handle `Flexible` widgets,
  // because `AnimationConfiguration.toStaggeredList` does not,
  // as of flutter_staggered_animations v0.1.2,
  static List<Widget> _toStaggeredList({
    Duration duration,
    Duration delay,
    @required Widget Function(Widget) childAnimationBuilder,
    @required List<Widget> children,
  }) =>
      children
          .asMap()
          .map((index, widget) {
            var child = widget is Flexible ? widget.child : widget;
            child = AnimationConfiguration.staggeredList(
              position: index,
              duration: duration,
              child: childAnimationBuilder(child),
            );
            child = widget is Flexible ? Flexible(child: child) : child;
            return MapEntry(
              index,
              child,
            );
          })
          .values
          .toList();
}