import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Home extends Asset {
  int nextGroupAddr = 1;

  Home() : super(const Uuid().v4(), 'Home');

  Home.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    nextGroupAddr = info['nextGroupAddr'] as int? ?? 1;
  }

  @override
  Map<String, dynamic> toJson() {
    additionalInfo ??= {};
    additionalInfo!['nextGroupAddr'] = nextGroupAddr;
    return super.toJson();
  }

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

class HomeInfo extends Home {
  String? customerTitle;
  bool? customerIsPublic;
  String homeProfileName = 'Home';

  HomeInfo.fromJson(Map<String, dynamic> json)
      : customerTitle = json['customerTitle'],
        customerIsPublic = json['customerIsPublic'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (customerTitle != null) json['customerTitle'] = customerTitle;
    if (customerIsPublic != null) json['customerIsPublic'] = customerIsPublic;
    json['assetProfileName'] = homeProfileName;
    return json;
  }

  @override
  String toString() {
    return 'HomeInfo{${assetString('homeProfileName: $homeProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
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
