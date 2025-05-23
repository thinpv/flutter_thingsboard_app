import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/modules/device/devices_base.dart';
import 'package:thingsboard_app/modules/device/devices_list.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

import 'provisioning/route/esp_provisioning_route.dart';

class DevicesListPage extends TbContextWidget {
  final String? deviceType;
  final bool? active;
  final bool searchMode;

  DevicesListPage(
    TbContext tbContext, {
    this.deviceType,
    this.active,
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DevicesListPageState();
}

class _DevicesListPageState extends TbContextState<DevicesListPage>
    with AutomaticKeepAliveClientMixin<DevicesListPage> {
  late final DeviceQueryController _deviceQueryController;

  @override
  void initState() {
    super.initState();
    _deviceQueryController = DeviceQueryController(
      deviceType: widget.deviceType,
      active: widget.active,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var devicesList = DevicesList(
      tbContext,
      _deviceQueryController,
      searchMode: widget.searchMode,
      displayDeviceImage: widget.deviceType == null,
    );
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) =>
            _deviceQueryController.onSearchText(searchText),
      );
    } else {
      String titleText = widget.deviceType != null
          ? widget.deviceType!
          : S.of(context).allDevices;
      String? subTitleText;
      if (widget.active != null) {
        subTitleText = widget.active == true
            ? S.of(context).active
            : S.of(context).inactive;
      }
      Column title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: subTitleText != null ? 16 : 20,
              height: subTitleText != null ? 20 / 16 : 24 / 20,
            ),
          ),
          if (subTitleText != null)
            Text(
              subTitleText,
              style: TextStyle(
                color: Theme.of(context)
                    .primaryTextTheme
                    .titleLarge!
                    .color!
                    .withAlpha((0.38 * 255).ceil()),
                fontSize: 12,
                fontWeight: FontWeight.normal,
                height: 16 / 12,
              ),
            ),
        ],
      );

      appBar = TbAppBar(
        tbContext,
        title: title,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              List<String> params = [];
              params.add('search=true');
              if (widget.deviceType != null) {
                params.add('deviceType=${widget.deviceType}');
              }
              if (widget.active != null) {
                params.add('active=${widget.active}');
              }
              navigateTo('/deviceList?${params.join('&')}');
            },
          ),
          PopupMenuButton(
            icon: Icon(Icons.add),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Add Device'),
                value: 1,
              ),
              PopupMenuItem(
                child: Text('Scan QR Code'),
                value: 2,
              ),
            ],
            onSelected: (value) async {
              if (value == 1) {
                final arguments = {
                  'deviceName': 'iotgw_64e833595394',
                  'deviceSecretKey': '',
                  'name': 'name_iotgw_64e833595394',
                  'pop': 'pop_abc',
                };

                bool? provisioningResult = await tbContext.navigateTo(
                  EspProvisioningRoute.softApRoute,
                  routeSettings: RouteSettings(arguments: arguments),
                );

                // bool? provisioningResult = await tbContext.navigateTo(
                //   EspProvisioningRoute.wifiRoute,
                //   routeSettings: RouteSettings(arguments: arguments),
                // );

                // if (provisioningResult == true) {
                //   return WidgetMobileActionResult.successResult(
                //     MobileActionResult.provisioning(arguments['deviceName']),
                //   );
                // } else {
                //   return WidgetMobileActionResult.emptyResult();
                // }
              } else if (value == 2) {
                try {
                  Barcode? barcode = await navigateTo('/qrCodeScan');
                  if (barcode != null && barcode.code != null) {
                    print('----------------> Barcode: ${barcode.code}');
                    final response = await tbClient
                        .getDeviceService()
                        .claimDevice(
                          barcode.code!,
                          ClaimRequest(secretKey: ''),
                          requestConfig: RequestConfig(ignoreErrors: true),
                        )
                        .timeout(
                          const Duration(seconds: 20),
                          onTimeout: () => throw Exception(
                              'Device claiming timeout reached'),
                        );

                    // if (response.response == ClaimResponse.CLAIMED ||
                    //     response.response == ClaimResponse.SUCCESS) {
                    //   communicationService.fire(
                    //     const DeviceProvisioningStatusChangedEvent(
                    //       DeviceProvisioningStatus.done,
                    //     ),
                    //   );
                    // } else {
                    //   emit(
                    //     const DeviceProvisioningClaimingErrorState(
                    //       'Something went wrong. Please try again.',
                    //     ),
                    //   );
                    // }
                  } else {}
                } catch (e) {
                  log.error(
                    'Login with qr code error',
                    e,
                  );
                }
              }
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: devicesList);
  }

  @override
  void dispose() {
    _deviceQueryController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
