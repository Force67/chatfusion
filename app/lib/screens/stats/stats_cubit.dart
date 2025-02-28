import 'package:bloc/bloc.dart';
import '../../services/ai_provider.dart';
import '../../models/llm.dart';

part 'stats_state.dart';

class BillingCubit extends Cubit<BillingState> {
  final AIProvider aiProvider;

  BillingCubit({required this.aiProvider}) : super(BillingInitial());

  Future<void> fetchBillingInfo() async {
    emit(BillingLoading());
    try {
      final billingInfo = await aiProvider.fetchBilling();
      if (billingInfo != null) {
        emit(BillingLoaded(billingInfo));
      } else {
        emit(BillingError("Billing information not available.")); // Handle null case explicitly
      }
    } catch (e) {
      emit(BillingError("Failed to fetch billing info: ${e.toString()}"));
    }
  }
}
