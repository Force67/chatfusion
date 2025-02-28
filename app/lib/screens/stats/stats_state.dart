part of 'stats_cubit.dart';

abstract class BillingState {}

class BillingInitial extends BillingState {}

class BillingLoading extends BillingState {}

class BillingLoaded extends BillingState {
  final BillingInfo billingInfo;

  BillingLoaded(this.billingInfo);
}

class BillingError extends BillingState {
  final String message;

  BillingError(this.message);
}
