import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:intl/intl.dart';
import 'package:thingsboard_app/constants/assets_path.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_profile_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/utils.dart';

mixin DevicesBase on EntitiesBase<DeviceInfo, PageLink> {
  @override
  String get title => 'Devices';

  @override
  String get noItemsFoundText => 'No devices found';

  @override
  Future<PageData<DeviceInfo>> fetchEntities(PageLink pageLink) {
    return DeviceManager.instance.getDeviceInfos(pageLink);
  }

  @override
  void onEntityTap(DeviceInfo deviceInfo) {
    var deviceProfile = DeviceProfileManager.instance
        .getDeviceProfileById(deviceInfo.deviceProfileId!.id!);
    if (deviceProfile?.defaultDashboardId != null) {
      var dashboardId = deviceProfile?.defaultDashboardId!.id!;
      var state = Utils.createDashboardEntityState(
        deviceInfo.id,
        entityName: deviceInfo.name,
        entityLabel: deviceInfo.label,
      );
      navigateToDashboard(
        dashboardId!,
        dashboardTitle: deviceInfo.name,
        state: state,
      );
    } else {
      navigateTo('/device/${deviceInfo.id?.id}');
    }
  }

  // @override
  // Future<void> onRefresh() {
  //   return Future.value();
  // }

  @override
  Widget buildEntityGridCard(
    BuildContext context,
    DeviceInfo deviceInfo,
  ) {
    return DeviceGridCard(tbContext, deviceInfo);
  }

  @override
  Widget buildEntityListCard(
    BuildContext context,
    DeviceInfo deviceInfo,
  ) {
    return _buildEntityListCard(context, deviceInfo, false);
  }

  @override
  Widget buildEntityListWidgetCard(
    BuildContext context,
    DeviceInfo deviceInfo,
  ) {
    return _buildEntityListCard(context, deviceInfo, true);
  }

  bool displayCardImage(bool listWidgetCard) => listWidgetCard;

  Widget _buildEntityListCard(
    BuildContext context,
    DeviceInfo deviceInfo,
    bool listWidgetCard,
  ) {
    return DeviceListCard(
      tbContext,
      deviceInfo: deviceInfo,
      listWidgetCard: listWidgetCard,
      displayImage: displayCardImage(listWidgetCard),
    );
  }

  @override
  double? gridChildAspectRatio() {
    return 156 / 200;
  }
}

class DeviceGridCard extends TbContextWidget {
  final DeviceInfo deviceInfo;

  DeviceGridCard(TbContext tbContext, this.deviceInfo, {super.key})
      : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DeviceGridCardState();
}

class _DeviceGridCardState extends TbContextState<DeviceGridCard> {
  @override
  Widget build(BuildContext context) {
    var entity = widget.deviceInfo;
    var deviceProfile = DeviceProfileManager.instance
        .getDeviceProfileById(entity.deviceProfileId!.id!);
    var hasImage = deviceProfile?.image != null;
    Widget image;
    BoxFit imageFit;
    double padding;
    if (hasImage) {
      image = Utils.imageFromTbImage(context, tbClient, deviceProfile?.image);
      imageFit = BoxFit.contain;
      padding = 8;
    } else {
      image = SvgPicture.asset(
        ThingsboardImage.deviceProfilePlaceholder,
        colorFilter: ColorFilter.mode(
          Theme.of(context).primaryColor,
          BlendMode.overlay,
        ),
        semanticsLabel: 'Device profile',
      );
      imageFit = BoxFit.cover;
      padding = 0;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: FittedBox(
                      clipBehavior: Clip.hardEdge,
                      fit: imageFit,
                      child: image,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: AutoSizeText(
                  entity.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  minFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceListCard extends TbContextWidget {
  final DeviceInfo deviceInfo;
  final bool listWidgetCard;
  final bool displayImage;

  DeviceListCard(
    TbContext tbContext, {
    super.key,
    required this.deviceInfo,
    this.listWidgetCard = false,
    this.displayImage = false,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DeviceListCardState();
}

class _DeviceListCardState extends TbContextState<DeviceListCard> {
  final entityDateFormat = DateFormat('yyyy-MM-dd');

  late Future<DeviceProfileInfo> deviceProfileFuture;

  @override
  void initState() {
    super.initState();
    if (widget.displayImage || !widget.listWidgetCard) {
      deviceProfileFuture = Future.value(DeviceProfileManager.instance
          .getDeviceProfileById(widget.deviceInfo.deviceProfileId!.id!));
    }
  }

  @override
  void didUpdateWidget(DeviceListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.displayImage || !widget.listWidgetCard) {
      var oldDeviceProfile = oldWidget.deviceInfo;
      var deviceInfo = widget.deviceInfo;
      if (oldDeviceProfile.deviceProfileId!.id! !=
          deviceInfo.deviceProfileId!.id!) {
        deviceProfileFuture = Future.value(DeviceProfileManager.instance
            .getDeviceProfileById(widget.deviceInfo.deviceProfileId!.id!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listWidgetCard) {
      return buildListWidgetCard(context);
    } else {
      return buildCard(context);
    }
  }

  Widget buildCard(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: (widget.deviceInfo.active ?? false)
                    ? const Color(0xFF008A00)
                    : const Color(0xFFAFAFAF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
        FutureBuilder<DeviceProfileInfo>(
          future: deviceProfileFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done) {
              var profile = snapshot.data!;
              bool hasDashboard = profile.defaultDashboardId != null;
              Widget image;
              BoxFit imageFit;
              if (profile.image != null) {
                image =
                    Utils.imageFromTbImage(context, tbClient, profile.image!);
                imageFit = BoxFit.contain;
              } else {
                image = SvgPicture.asset(
                  ThingsboardImage.deviceProfilePlaceholder,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).primaryColor,
                    BlendMode.overlay,
                  ),
                  semanticsLabel: 'Device',
                );
                imageFit = BoxFit.cover;
              }
              return Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 20),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.displayImage)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(4),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(4),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: FittedBox(
                                          fit: imageFit,
                                          child: image,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Flexible(
                              fit: FlexFit.tight,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            widget.deviceInfo.name,
                                            style: const TextStyle(
                                              color: Color(
                                                0xFF282828,
                                              ),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              height: 20 / 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        entityDateFormat.format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            widget.deviceInfo.createdTime!,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFFAFAFAF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                          height: 16 / 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.deviceInfo.deviceProfileName ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFFAFAFAF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                          height: 16 / 12,
                                        ),
                                      ),
                                      Text(
                                        widget.deviceInfo.active ?? false
                                            ? S.of(context).active
                                            : S.of(context).inactive,
                                        style: TextStyle(
                                          color:
                                              widget.deviceInfo.active ?? false
                                                  ? const Color(0xFF008A00)
                                                  : const Color(0xFFAFAFAF),
                                          fontSize: 12,
                                          height: 16 / 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (hasDashboard)
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFACACAC),
                              ),
                            if (hasDashboard) const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return SizedBox(
                height: 64,
                child: Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(tbContext.currentState!.context)
                          .colorScheme
                          .primary,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget buildListWidgetCard(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.displayImage)
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              // color: Color(0xFFEEEEEE),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
            ),
            child: FutureBuilder<DeviceProfileInfo>(
              future: deviceProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.done) {
                  var profile = snapshot.data!;
                  Widget image;
                  BoxFit imageFit;
                  if (profile.image != null) {
                    image = Utils.imageFromTbImage(
                      context,
                      tbClient,
                      profile.image!,
                    );
                    imageFit = BoxFit.contain;
                  } else {
                    image = SvgPicture.asset(
                      ThingsboardImage.deviceProfilePlaceholder,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).primaryColor,
                        BlendMode.overlay,
                      ),
                      semanticsLabel: 'Device',
                    );
                    imageFit = BoxFit.cover;
                  }
                  return ClipRRect(
                    borderRadius:
                        const BorderRadius.horizontal(left: Radius.circular(4)),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FittedBox(
                            fit: imageFit,
                            child: image,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: RefreshProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(tbContext.currentState!.context)
                            .colorScheme
                            .primary,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.deviceInfo.name,
                        style: const TextStyle(
                          color: Color(0xFF282828),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.deviceInfo.deviceProfileId!.id!,
                      style: const TextStyle(
                        color: Color(0xFFAFAFAF),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StrikeThroughPainter extends CustomPainter {
  final Color color;
  final double offset;

  StrikeThroughPainter({required this.color, this.offset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    paint.strokeWidth = 1.5;
    canvas.drawLine(
      Offset(offset, offset),
      Offset(size.width - offset, size.height - offset),
      paint,
    );
    paint.color = Colors.white;
    canvas.drawLine(
      const Offset(2, 0),
      Offset(size.width + 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant StrikeThroughPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
