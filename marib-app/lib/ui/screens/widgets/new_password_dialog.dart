import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';

class NewPasswordDialog extends StatefulWidget {
  final Function(String password) onPasswordSet;
  final VoidCallback onCancel;

  const NewPasswordDialog({
    super.key,
    required this.onPasswordSet,
    required this.onCancel,
  });

  @override
  State<NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<NewPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.color.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(
        "newPassword".translate(context),
        style: TextStyle(
          fontSize: context.font.extraLarge,
          color: context.color.textDefaultColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "pleaseEnterNewPassword".translate(context),
              style: TextStyle(
                fontSize: context.font.normal,
                color: context.color.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomTextFormField(
              controller: _passwordController,
              hintText: "newPassword".translate(context),
              obscureText: _isObscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _isObscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: context.color.textColor,
                ),
                onPressed: () {
                  setState(() {
                    _isObscurePassword = !_isObscurePassword;
                  });
                },
              ),
              validator: CustomTextFieldValidator.password,
            ),
            const SizedBox(height: 15),
            CustomTextFormField(
              controller: _confirmPasswordController,
              hintText: "confirmPassword".translate(context),
              obscureText: _isObscureConfirmPassword,
              suffix: IconButton(
                icon: Icon(
                  _isObscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: context.color.textColor,
                ),
                onPressed: () {
                  setState(() {
                    _isObscureConfirmPassword = !_isObscureConfirmPassword;
                  });
                },
              ),
              validator: CustomTextFieldValidator.nullCheck,
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.color.textColor,
                  side: BorderSide(color: context.color.textColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("cancel".translate(context)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // التحقق من تطابق كلمات المرور
                    if (_passwordController.text !=
                        _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text("passwordsDoNotMatch".translate(context)),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    widget.onPasswordSet(_passwordController.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("save".translate(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
