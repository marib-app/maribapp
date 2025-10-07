import 'package:lottie/lottie.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';

class NoDataFound extends StatelessWidget {
  final double? height;
  final String? mainMessage;
  final String? subMessage;
  final VoidCallback? onTap;

  const NoDataFound(
      {super.key, this.onTap, this.height, this.mainMessage, this.subMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height ?? 200,
            // child: UiUtils.getSvg(
            //   AppIcons.no_data_found,
            // ),

            child: Lottie.asset(
              'assets/lottie/no_data.json', // Replace with your Lottie file path
              width: 200, // Adjust the width as needed
              height: 200, // Adjust the height as needed
              fit: BoxFit.fill, // Adjust the fit if necessary
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Text(mainMessage == null
                  ? "nodatafound".translate(context)
                  : mainMessage!)
              .size(context.font.extraLarge)
              .color(context.color.territoryColor)
              .bold(weight: FontWeight.w600),
          const SizedBox(
            height: 14,
          ),
          Text(subMessage == null
                  ? "sorryLookingFor".translate(context)
                  : subMessage!)
              .size(context.font.larger)
              .centerAlign(),
          // Text(UiUtils.getTranslatedLabel(context, "nodatafound")),
          // TextButton(
          //     onPressed: onTap,
          //     style: ButtonStyle(
          //         overlayColor: MaterialStateItem.all(
          //             context.color.teritoryColor.withOpacity(0.2))),
          //     child: const Text("Retry").color(context.color.teritoryColor))
        ],
      ),
    );
  }
}
