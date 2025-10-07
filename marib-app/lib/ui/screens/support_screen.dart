import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/data/cubits/request_device/request_device_cubit.dart';
import 'package:marib/data/cubits/request_support/request_support_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'dart:ui' as ui;

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => SupportScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const SupportScreen(),
    );
  }
}

class SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF7F2),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(
            "support".translate(context),
            style: const TextStyle(color: Colors.black),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF35A00), Color(0xFFFFA726)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مرحباً، كيف يمكننا مساعدتك؟',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.message_outlined),
                      label: const Text('إرسال رسالة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFF35A00),
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        print("Messages button pressed");
                      },
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('الرسائل المخزنة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFF35A00),
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "feedbackMessage".translate(context),
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              SendWidget(
                phone: HiveUtils.getUserDetails().mobile?.toString() ?? '',
                name: HiveUtils.getUserDetails().name?.toString() ?? '',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class SendWidget extends StatefulWidget {
  final String phone;
  final String name;

  const SendWidget({
    super.key,
    required this.phone,
    required this.name,
  });

  @override
  State<SendWidget> createState() => _SendWidgetState();
}

class _SendWidgetState extends State<SendWidget> {
  final TextEditingController _subject = TextEditingController();
  late final TextEditingController _phone =
      TextEditingController(text: widget.phone);
  late final TextEditingController _name =
      TextEditingController(text: widget.name);
  final TextEditingController _text = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildInputField(
            controller: _name,
            hint: "fullName".translate(context),
          ),
          _buildInputField(
            controller: _phone,
            hint: "phoneNumber".translate(context),
            keyboardType: TextInputType.phone,
          ),
          _buildInputField(
            controller: _subject,
            hint: "subject".translate(context),
          ),
          _buildInputField(
            controller: _text,
            hint: "writeRequestClearly".translate(context),
            lines: 4,
          ),
          const SizedBox(height: 20),
          BlocConsumer<RequestSupportCubit, RequestSupportState>(
            listener: (context, state) {
              if (state is RequestSupportSuccess) {
                UiUtils.showBlurredDialoge(
                  context,
                  dialoge: BlurredDialogBox(
                    title: "requestSentSuccessfully".translate(context),
                    content: Text(
                      "requestSentSuccessMessage".translate(context),
                      style: const TextStyle(fontSize: 16),
                    ),
                    showCancleButton: false,
                  ),
                );
                _subject.clear();
                _text.clear();
              } else if (state is RequestSupportFailure) {
                HelperUtils.showSnackBarMessage(
                  context,
                  state.error,
                  messageDuration: 3,
                );
              }
            },
            builder: (context, state) {
              return ElevatedButton.icon(
                onPressed: () {
                  if (_subject.text.isEmpty || _text.text.isEmpty) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "pleaseFillAllFields".translate(context),
                      messageDuration: 3,
                    );
                    return;
                  }
                  context.read<RequestSupportCubit>().requestSupport(
                        name: _name.text,
                        phone: _phone.text,
                        subject: _subject.text,
                        message: _text.text,
                      );
                },
                icon: state is RequestSupportInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  state is RequestSupportInProgress
                      ? "sending".translate(context)
                      : "submit".translate(context),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF35A00),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    int lines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: lines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}
