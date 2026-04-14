import 'package:thingsboard_app/modules/main/model/navigation_type.dart';

abstract final class ThingsboardAppConstants {
  static const thingsBoardApiEndpoint = String.fromEnvironment(
    'thingsboardApiEndpoint',
    defaultValue: 'https://34.142.253.96.nip.io',
  );

  /// Override middleware base URL. Nếu không set (empty), HomeService tự
  /// derive từ thingsBoardApiEndpoint: same scheme+host + /mpipe.
  /// Local dev (không qua nginx): dart-define=middlewareUrl=http://localhost:3000
  static const middlewareUrl = String.fromEnvironment('middlewareUrl');
  static const thingsboardOAuth2CallbackUrlScheme = String.fromEnvironment(
    'thingsboardOAuth2CallbackUrlScheme',
  );
  static const thingsboardIOSAppSecret = String.fromEnvironment(
    'thingsboardIosAppSecret',
  );
  static const thingsboardAndroidAppSecret = String.fromEnvironment(
    'thingsboardAndroidAppSecret',
  );
  static const ignoreRegionSelection = thingsBoardApiEndpoint != '';
  static final navigationType = 
  TbNavigationType.fromString(
  const String.fromEnvironment('navigationType'),
  );
}
