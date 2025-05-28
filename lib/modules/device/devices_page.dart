import 'dart:convert';

import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'devices_list.dart';
import 'provisioning/route/esp_provisioning_route.dart';

class DevicesPage extends TbContextWidget {
  final bool searchMode;

  DevicesPage(
    TbContext tbContext, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DevicesPageState();
}

class _DevicesPageState extends TbContextState<DevicesPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final devicesList = DevicesList(
      tbContext,
      _pageLinkController,
      searchMode: widget.searchMode,
    );
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) => _pageLinkController.onSearchText(searchText),
      );
    } else {
      appBar = TbAppBar(
        tbContext,
        title: Text(devicesList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/devices?search=true');
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
      );
    }
    return Scaffold(appBar: appBar, body: devicesList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
