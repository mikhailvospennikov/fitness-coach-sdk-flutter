import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ZingProgramView extends StatelessWidget {
  const ZingProgramView({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return const UiKitView(viewType: 'zing_sdk_initializer/program_view');
  }
}
