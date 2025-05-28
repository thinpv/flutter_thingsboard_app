import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:thingsboard_app/constants/assets_path.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_profile_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/utils.dart';

mixin DevicesGridBase on EntitiesBase<DeviceInfo, PageLink> {
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
    return DeviceCard(tbContext, deviceInfo);
  }

  @override
  double? gridChildAspectRatio() {
    return 156 / 200;
  }
}

class DeviceCard extends TbContextWidget {
  final DeviceInfo deviceInfo;

  DeviceCard(TbContext tbContext, this.deviceInfo, {super.key})
      : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DeviceCardState();
}

class _DeviceCardState extends TbContextState<DeviceCard> {
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
