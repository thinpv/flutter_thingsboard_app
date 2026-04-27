import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/app_colors.dart';
import 'package:thingsboard_app/config/themes/tb_text_styles.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/generated/l10n.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/more/profle_widget.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/overlay_service/i_overlay_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/auth_middleware_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// "Delete account" row for the Profile preview.
///
/// CUSTOMER_USER accounts can only be deleted via the mPipe middleware
/// (TB CE rejects /api/user DELETE for non-admin authorities). Tenant admins
/// fall back to the direct TB API since they have permission.
Widget getDeleteButton(BuildContext context, WidgetRef ref, User user) {
  return Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Divider(),
      ),
      TextButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textError,
          padding: const EdgeInsets.all(16),
        ),
        onPressed: () async {
          await deleteAccount(context, ref, user);
        },
        child: Row(
          spacing: 4,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever),
            Text(S.of(context).deleteAccount, style: TbTextStyles.labelMedium),
          ],
        ),
      ),
    ],
  );
}

Future<void> deleteAccount(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final delete = await getIt<IOverlayService>().showConfirmDialog(
    content:
        (_) => DialogContent(
          title: S.of(context).deleteAccount,
          message: S
              .of(context)
              .accountDeletionDialogBody(
                getAuthorityName(context, user).toLowerCase(),
              ),
          cancel: S.of(context).cancel,
        ),
  );
  if (delete != true) return;

  final client = getIt<ITbClientService>().client;
  try {
    if (user.authority == Authority.CUSTOMER_USER) {
      // Customer self-delete must go through mPipe middleware — TB CE doesn't
      // grant CUSTOMER_USER permission to call DELETE /api/user. Middleware
      // re-verifies the token, then deletes user + customer with tenant creds.
      final token = client.getJwtToken();
      if (token == null || token.isEmpty) {
        throw Exception('No active session');
      }
      await AuthMiddlewareService().deleteAccount(token);
    } else if (user.authority == Authority.TENANT_ADMIN) {
      // Tenants delete the whole tenant entity directly — they have the
      // permission already.
      await client.getTenantService().deleteTenant(user.tenantId!.id!);
    } else {
      throw Exception('Unsupported authority for self-deletion');
    }
    await ref.read(loginProvider.notifier).logout();
  } catch (e) {
    getIt<IOverlayService>().showErrorNotification(
      (_) => S.of(context).cantDeleteUserAccount,
      duration: const Duration(milliseconds: 1500),
    );
  }
}
