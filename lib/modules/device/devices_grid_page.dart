import 'dart:convert';

import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'devices_grid.dart';
import 'provisioning/route/esp_provisioning_route.dart';

class DevicesGridPage extends TbContextWidget {
  DevicesGridPage(TbContext tbContext, {super.key}) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DevicesMainPageState();
}

class _DevicesMainPageState extends TbContextState<DevicesGridPage>
    with AutomaticKeepAliveClientMixin<DevicesGridPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  bool get wantKeepAlive {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final deviceInfosList = DevicesGrid(
      tbContext,
      _pageLinkController,
    );

    return Scaffold(
      appBar: TbAppBar(
        tbContext,
        title: Text(deviceInfosList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/deviceList?search=true');
            },
          ),
          PopupMenuButton(
            icon: Icon(Icons.add),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Scan QR Code'),
                value: 1,
              ),
              PopupMenuItem(
                child: Text('Add Device (BLE mode)'),
                value: 2,
              ),
              PopupMenuItem(
                child: Text('Add Device (AP mode)'),
                value: 3,
              ),
            ],
            onSelected: (value) async {
              if (value == 1) {
                try {
                  Barcode? barcode = await tbContext.navigateTo(
                    '/qrCodeScan',
                    transition: TransitionType.nativeModal,
                  );
                  if (barcode != null && barcode.code != null) {
                    final decodedJson = jsonDecode(barcode.code!);
                    final transport = decodedJson?['transport'];
                    if (transport != null) {
                      final arguments = {
                        'deviceName':
                            decodedJson['tbDeviceName'] ?? decodedJson['name'],
                        'deviceSecretKey':
                            decodedJson['tbSecretKey'] ?? decodedJson['pop'],
                        'name':
                            decodedJson['name'] ?? decodedJson['tbDeviceName'],
                        'pop': decodedJson['pop'] ?? decodedJson['tbSecretKey'],
                      };

                      switch (transport.toLowerCase()) {
                        case 'ble':
                          tbContext.navigateTo(
                            EspProvisioningRoute.wifiRoute,
                            routeSettings: RouteSettings(arguments: arguments),
                          );
                          break;

                        case 'softap':
                          tbContext.navigateTo(
                            EspProvisioningRoute.softApRoute,
                            routeSettings: RouteSettings(arguments: arguments),
                          );
                          break;

                        case 'name':
                          tbClient
                              .getDeviceService()
                              .claimDevice(
                                barcode.code!,
                                ClaimRequest(secretKey: ''),
                                requestConfig:
                                    RequestConfig(ignoreErrors: true),
                              )
                              .timeout(
                                const Duration(seconds: 20),
                                onTimeout: () => throw Exception(
                                    'Device claiming timeout reached'),
                              );
                          break;
                      }
                    }
                  }
                } catch (e) {
                  tbContext.log.error(
                    'Login with qr code error',
                    e,
                  );
                }
              } else if (value == 2) {
                final arguments = {
                  'deviceName': '',
                  'deviceSecretKey': '',
                  'name': 'iotgw_',
                  'pop': 'thinpv1607',
                };
                tbContext.navigateTo(
                  EspProvisioningRoute.wifiRoute,
                  routeSettings: RouteSettings(arguments: arguments),
                );
              } else if (value == 3) {
                final arguments = {
                  'deviceName': '',
                  'deviceSecretKey': '',
                  'name': 'iotgw_',
                  'pop': 'thinpv1607',
                };
                tbContext.navigateTo(
                  EspProvisioningRoute.softApRoute,
                  routeSettings: RouteSettings(arguments: arguments),
                );
              }
            },
          ),
        ],
      ),
      body: deviceInfosList,
    );
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
