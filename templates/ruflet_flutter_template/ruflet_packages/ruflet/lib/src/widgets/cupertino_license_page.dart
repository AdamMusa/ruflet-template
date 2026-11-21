import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'control_route.dart';

/// iOS licenses page (D-7): Flutter only ships the Material [LicensePage].
///
/// Lists the [LicenseRegistry] packages in an inset-grouped section (package
/// name, number of licenses, chevron); a package opens its license text.
class CupertinoLicensePage extends StatefulWidget {
  final String? applicationName;
  final String? applicationVersion;
  final Widget? applicationIcon;
  final String? applicationLegalese;

  const CupertinoLicensePage({
    super.key,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  });

  @override
  State<CupertinoLicensePage> createState() => _CupertinoLicensePageState();
}

class _CupertinoLicensePageState extends State<CupertinoLicensePage> {
  late final Future<List<(String, List<LicenseEntry>)>> _packages =
      _loadPackages();

  static Future<List<(String, List<LicenseEntry>)>> _loadPackages() async {
    final byPackage = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [for (final name in names) (name, byPackage[name]!)];
  }

  Widget _header(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final name = widget.applicationName ?? "";
    final version = widget.applicationVersion ?? "";
    final legalese = widget.applicationLegalese ?? "";
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          if (widget.applicationIcon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: widget.applicationIcon!,
            ),
          if (name.isNotEmpty)
            Text(name,
                textAlign: TextAlign.center,
                style: textTheme.navTitleTextStyle),
          if (version.isNotEmpty)
            Text(version,
                textAlign: TextAlign.center,
                style: textTheme.textStyle.copyWith(color: secondary)),
          if (legalese.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(legalese,
                  textAlign: TextAlign.center,
                  style: textTheme.textStyle
                      .copyWith(fontSize: 13, color: secondary)),
            ),
        ],
      ),
    );
  }

  Widget _packageList(BuildContext context,
      AsyncSnapshot<List<(String, List<LicenseEntry>)>> snapshot) {
    final packages = snapshot.data;
    if (packages == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: CupertinoActivityIndicator(),
      );
    }
    if (packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text("No licenses", textAlign: TextAlign.center),
      );
    }
    return CupertinoListSection.insetGrouped(
      children: [
        for (final (name, entries) in packages)
          CupertinoListTile(
            title: Text(name),
            additionalInfo: Text("${entries.length}"),
            trailing: const CupertinoListTileChevron(),
            // Carries the page's themes (and a dialog's ControlRouteScope).
            onTap: () => pushCarryingThemes(
              context,
              (wrap) => CupertinoPageRoute<void>(
                builder: (_) => wrap(_CupertinoPackageLicensePage(
                    package: name, entries: entries)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: const CupertinoNavigationBar(middle: Text("Licenses")),
      child: FutureBuilder<List<(String, List<LicenseEntry>)>>(
        future: _packages,
        builder: (context, snapshot) => ListView(
          children: [_header(context), _packageList(context, snapshot)],
        ),
      ),
    );
  }
}

/// The license texts of one package; [LicenseParagraph.indent] becomes a
/// 16 px leading inset and centered paragraphs stay centered.
class _CupertinoPackageLicensePage extends StatelessWidget {
  final String package;
  final List<LicenseEntry> entries;

  const _CupertinoPackageLicensePage(
      {required this.package, required this.entries});

  static const _indent = 16.0;

  @override
  Widget build(BuildContext context) {
    final style =
        CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 13);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final children = <Widget>[];
    for (final entry in entries) {
      if (children.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(height: 0.5, child: ColoredBox(color: separator)),
        ));
      }
      for (final paragraph in entry.paragraphs) {
        final centered = paragraph.indent == LicenseParagraph.centeredIndent;
        children.add(Padding(
          padding: EdgeInsetsDirectional.only(
              top: 8, start: centered ? 0 : _indent * paragraph.indent),
          child: Text(paragraph.text,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: centered
                  ? style.copyWith(fontWeight: FontWeight.w600)
                  : style),
        ));
      }
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
          middle: Text(package), previousPageTitle: "Licenses"),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
    );
  }
}
