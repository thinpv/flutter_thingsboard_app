import 'package:thingsboard_app/service/home_service.dart';
import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Home extends Asset {
  Home() : super(const Uuid().v4(), 'Home');

  Home.fromJson(super.json) : super.fromJson();

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}

class HomeAdd extends Home {
  HomeAdd() : super();
}

class HomeInfo extends AssetInfo {
  HomeInfo.fromJson(super.json) : super.fromJson();

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}

class HomeSearchQuery extends EntitySearchQuery {
  List<String> homeTypes;

  HomeSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.homeTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['homeTypes'] = homeTypes;
    return json;
  }

  @override
  String toString() {
    return 'HomeSearchQuery{${entitySearchQueryString('homeTypes: $homeTypes')}}';
  }
}
