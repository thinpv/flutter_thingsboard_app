/// Metadata cho một RPC method mà thiết bị hỗ trợ.
/// Dùng trong ProfileMetadata.actions.
class ActionMetaDef {
  const ActionMetaDef({this.paramsHint = const []});

  factory ActionMetaDef.fromJson(Map<String, dynamic> json) {
    return ActionMetaDef(
      paramsHint: (json['paramsHint'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Tên params mà method này nhận (hint cho UI).
  /// Ví dụ: setValue → ['onoff0'], toggle → []
  final List<String> paramsHint;

  Map<String, dynamic> toJson() => {
        'paramsHint': paramsHint,
      };
}
