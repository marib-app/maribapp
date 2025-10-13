
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/competition_cubit.dart';
import 'package:marib/data/model/challenge_model.dart';
import 'package:marib/data/repositories/competition_repository.dart';
import 'package:marib/ui/screens/competitions/competition_share_info.dart';
import 'package:marib/ui/screens/competitions/competition_support.dart';
import 'package:marib/ui/screens/competitions/competitions_screen_ui.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';


class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});



  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (_) =>
        CompetitionCubit(CompetitionRepository())..fetchCompetitionData(),
        child: const CompetitionScreen(),
      ),
    );
  }

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}





class _CompetitionScreenState extends State<CompetitionScreen>
    with TickerProviderStateMixin {



  late final TabController _tabController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  final CompetitionLogic _logic = const CompetitionLogic();

  bool _showWarning = false;


  @override
  void initState() {
    super.initState();



    _tabController = TabController(length: 2, vsync: this);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

  }

  @override
  void dispose() {
    _tabController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  bool _handleCollect(int currentPoints, List<Challenge> challenges) {
    final canCollect = _logic.hasCollectibleReward(challenges, currentPoints);
    if (!canCollect) {
      _shakeController.forward(from: 0);
    }

    return canCollect;

  }

  Future<void> _savePaymentInfo({
    required List<String> paymentMethods,
    required Map<String, dynamic> paymentAccountDetails,
    String? businessName,
    String? businessWhatsapp,
    String? businessLocation,
    List<String>? businessCategories,
    String? commercialRegister,
    String? email,
  }) {
    return context.read<CompetitionCubit>().savePaymentInfo(
      paymentMethods: paymentMethods,
      paymentAccountDetails: paymentAccountDetails,
      businessName: businessName,
      businessWhatsapp: businessWhatsapp,
      businessLocation: businessLocation,
      businessCategories: businessCategories,
      commercialRegister: commercialRegister,
      email: email,

        );
  }

  void _openInstructions() {
    final cubit = context.read<CompetitionCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const CompetitionShareInfoScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = CompetitionActions(
      onWarningFlagGetter: () => _showWarning,
      onWarningFlagSetter: (flag) {
        if (!mounted || _showWarning == flag) {
          return;
        }
        setState(() => _showWarning = flag);
      },
      onTryCollect: _handleCollect,
      onShakeAnimation: () {
        if (!_shakeController.isAnimating) {
          _shakeController.forward(from: 0);
        }
        return _shakeAnimation;
      },
      goToChallengeInstructions: _openInstructions,
      onSavePaymentInfo: ({
        required paymentMethods,
        required paymentAccountDetails,
        String? businessName,
        String? businessWhatsapp,
        String? businessLocation,
        List<String>? businessCategories,
        String? commercialRegister,
        String? email,
      }) {
        return _savePaymentInfo(
          paymentMethods: paymentMethods,
          paymentAccountDetails: paymentAccountDetails,
          businessName: businessName,
          businessWhatsapp: businessWhatsapp,
          businessLocation: businessLocation,
          businessCategories: businessCategories,
          commercialRegister: commercialRegister,
          email: email,
        );
      },
    );


    return BlocBuilder<CompetitionCubit, CompetitionState>(
      builder: (context, state) {
        return CompetitionScreenUI(
          tabController: _tabController,
          state: state,
          logic: _logic,
          actions: actions,
        );
      },
    );
  }
}


