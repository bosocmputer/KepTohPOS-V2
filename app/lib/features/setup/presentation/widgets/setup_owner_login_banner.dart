import 'package:app/core/di/injection.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/onboarding/presentation/owner_login_form.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';

/// Asks for the owner's login, which real shops need to change setup data.
class SetupOwnerLoginBanner extends StatefulWidget {
  const new({super.key});

  @override
  State<SetupOwnerLoginBanner> createState() => _SetupOwnerLoginBannerState();
}

class _SetupOwnerLoginBannerState extends State<SetupOwnerLoginBanner> {
  bool _signedIn = false;

  @override
  Widget build(BuildContext context) {
    if (_signedIn) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: SetupCard(
        key: const ValueKey('setup-owner-login-banner'),
        padding: const EdgeInsets.all(AppDimensions.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'เข้าสู่ระบบบัญชีเจ้าของร้านเพื่อแก้ไขข้อมูลร้าน',
              style: tt.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space3),
            OwnerLoginForm(
              session: sl<DeviceSession>(),
              onSignedIn: () => setState(() => _signedIn = true),
            ),
          ],
        ),
      ),
    );
  }
}
