import 'package:flutter/widgets.dart';

/// Normalizes external URIs (e.g. `ruflet://ruflet-host/aaa`) into the path-based
/// form used by Ruflet routing (e.g. `/aaa`).
class RufletRouteInformationProvider extends PlatformRouteInformationProvider {
  RufletRouteInformationProvider({
    required super.initialRouteInformation,
  });

  static RouteInformation normalize(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    return RouteInformation(
      uri: Uri(
        path: uri.path.isEmpty ? '/' : uri.path,
        query: uri.hasQuery ? uri.query : null,
        fragment: uri.hasFragment ? uri.fragment : null,
      ),
      state: routeInformation.state,
    );
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final normalized = normalize(routeInformation);
    debugPrint(
        "RufletRouteInformationProvider.didPushRouteInformation: ${routeInformation.uri} -> ${normalized.uri}");
    return super.didPushRouteInformation(normalized);
  }
}

class RufletLocalRouteInformationProvider extends RouteInformationProvider
    with ChangeNotifier {
  RouteInformation _value;

  RufletLocalRouteInformationProvider({
    required RouteInformation initialRouteInformation,
  }) : _value = RufletRouteInformationProvider.normalize(
            initialRouteInformation,
          );

  @override
  RouteInformation get value => _value;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    _setValue(routeInformation);
  }

  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    _setValue(routeInformation);
    return true;
  }

  void _setValue(RouteInformation routeInformation) {
    final normalized = RufletRouteInformationProvider.normalize(routeInformation);
    if (_value.uri == normalized.uri && _value.state == normalized.state) {
      return;
    }
    _value = normalized;
    notifyListeners();
  }
}
