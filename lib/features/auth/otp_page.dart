import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/brand.dart';
import '../../controllers/auth_controller.dart';
import '../../services/exceptions.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/brand_badge.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/primary_scaffold.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  int _step = 0;
  String? _status;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = serviceProvider.get<NotificationService>();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.9 + (0.1 * value),
                child: child,
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Consumer<AuthController>(
                  builder: (context, auth, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandBadge(),
                        const SizedBox(height: 24),
                        Text(
                          'ورود به ${Brand.name}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 0
                              ? 'برای ورود، شماره موبایل خود را وارد کنید.'
                              : 'کد ۶ رقمی ارسال شده را وارد کنید.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        if (_status != null)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(76),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _status!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_status != null) const SizedBox(height: 16),
                        if (_step == 0)
                          _buildPhoneForm(context, auth)
                        else
                          _buildCodeForm(context, auth),
                        const SizedBox(height: 24),
                        if (auth.isSubmitting)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else
                          ImprovedButton(
                            onPressed: () => _step == 0
                                ? _handleRequestOtp(auth)
                                : _handleVerifyOtp(auth),
                            icon: _step == 0
                                ? Icons.sms_outlined
                                : Icons.verified_user,
                            variant: ButtonVariant.elevated,
                            child:
                                Text(_step == 0 ? 'دریافت کد تایید' : 'ورود'),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _step == 0
                              ? null
                              : () {
                                  setState(() => _step = 0);
                                },
                          child: const Text('ویرایش شماره'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm(BuildContext context, AuthController auth) {
    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'شماره موبایل',
          hintText: 'مثال: 09121234567',
        ),
        validator: (value) {
          final phone = value?.trim() ?? '';
          if (phone.isEmpty) {
            return 'شماره موبایل را وارد کنید.';
          }
          if (phone.length < 10) {
            return 'شماره معتبر نیست.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCodeForm(BuildContext context, AuthController auth) {
    return Form(
      key: _codeKey,
      child: TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'کد تایید',
          hintText: '******',
        ),
        maxLength: 6,
        validator: (value) {
          final code = value?.trim() ?? '';
          if (code.length != 6) {
            return 'کد باید ۶ رقم باشد.';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _handleRequestOtp(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _normalizePhone(_phoneController.text);
    try {
      final detail = await auth.requestOtp(phone);
      setState(() {
        _status = detail;
        _step = 1;
      });
      _notificationService.showLocalNow(
        title: 'کد تایید ارسال شد',
        body: detail,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _handleVerifyOtp(AuthController auth) async {
    if (!_codeKey.currentState!.validate()) return;
    try {
      final profileService = context.read<UserProfileService>();
      await auth.verifyOtp(_codeController.text.trim());
      await profileService.getProfile();
    } catch (error) {
      if (mounted) {
        _showError(error);
      } else {
        // The page was unmounted, probably during navigation.
        // We can log it, but not show it to the user.
        print("Error in _handleVerifyOtp after unmount: $error");
      }
    }
  }

  void _showError(Object error) {
    final message =
        error is ApiException ? error.message : 'خطای ناشناخته رخ داد.';
    _notificationService.showLocalNow(title: 'خطا', body: message);
  }

  String _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('0')) {
      return '+98${cleaned.substring(1)}';
    }
    if (!cleaned.startsWith('+98')) {
      return '+98$cleaned';
    }
    return cleaned;
  }
}
