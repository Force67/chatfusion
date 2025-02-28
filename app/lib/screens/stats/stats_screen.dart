import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'stats_cubit.dart';
import '../../services/ai_provider.dart';

class StatsOverview extends StatelessWidget {
  const StatsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // Wrap with Scaffold to add AppBar and back button
      appBar: AppBar(
        title: Text("Billing Statistics",
            style: textTheme.titleLarge
                ?.copyWith(color: colorScheme.onPrimary)), // Themed title
        backgroundColor: colorScheme.primary, // Themed AppBar background
        foregroundColor: colorScheme.onPrimary, // Themed AppBar text/icon color
        elevation: 2, // AppBar elevation
        leading: IconButton(
          // Back button
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // Navigate back
          },
        ),
      ),
      body: BlocBuilder<BillingCubit, BillingState>(
        builder: (context, state) {
          if (state is BillingLoading) {
            return Center(
                child: CircularProgressIndicator(
                    color: colorScheme.primary)); // Themed loading indicator
          } else if (state is BillingError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24.0), // Added padding for error state
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: colorScheme.error,
                        size: 60), // Themed error icon, larger size
                    const SizedBox(height: 24),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error), // Themed error text
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      // Styled Retry button
                      onPressed: () {
                        context.read<BillingCubit>().fetchBillingInfo();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            colorScheme.primary, // Primary color for button
                        foregroundColor:
                            colorScheme.onPrimary, // Text color on primary
                        elevation: 3, // Button elevation
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)), // Rounded button
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12), // Button padding
                      ),
                      child: Text('Retry',
                          style: textTheme.labelLarge?.copyWith(
                              color:
                                  colorScheme.onPrimary)), // Themed button text
                    ),
                  ],
                ),
              ),
            );
          } else if (state is BillingLoaded) {
            return _buildBillingInfoCard(
                state.billingInfo, context); // Pass context for theming
          } else {
            context.read<BillingCubit>().fetchBillingInfo();
            // Initial state or other unexpected state - maybe fetch on init?
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Tap to load stats",
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface
                          .withOpacity(0.6)), // Muted placeholder text
                  textAlign: TextAlign.center,
                ),
              ),
            ); // Placeholder for initial
          }
        },
      ),
    );
  }

  Widget _buildBillingInfoCard(BillingInfo billingInfo, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 8, // Increased elevation for more shadow
      margin: const EdgeInsets.all(20), // Slightly larger margin
      color: colorScheme.surface, // Card background color from theme
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)), // More rounded corners
      child: Padding(
        padding: const EdgeInsets.all(24), // Increased padding inside card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Make card shrink to content
          children: [
            Text(
              "Billing Overview",
              style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      colorScheme.onSurface), // Themed title, slightly bolder
            ),
            const SizedBox(height: 24), // Increased spacing
            _buildStatRow(
              context: context, // Pass context for theming
              icon: Icons.trending_up, // Usage icon
              label: "Usage",
              value:
                  "${billingInfo.usage.toStringAsFixed(2)} / ${billingInfo.limit.toStringAsFixed(2)}", // Format decimals
              unit: "credits", // Assuming 'credits' as unit, adjust as needed.
              isPercentage: billingInfo.limit >
                  0, // Show progress bar only if limit is set
              currentValue: billingInfo.usage,
              maxValue: billingInfo.limit,
            ),
            const SizedBox(height: 20), // Increased spacing
            _buildStatRow(
              context: context, // Pass context for theming
              icon: Icons.request_page, // Request icon
              label: "Max Requests",
              value: billingInfo.maxRequests
                  .toInt()
                  .toString(), // Assuming requests are integers
              unit: "requests",
            ),
            // You can add more stats rows here if you decide to expand billing info
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required BuildContext context, // Context for theming
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    bool isPercentage = false,
    double? currentValue,
    double? maxValue,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Row(
      children: [
        Icon(icon, color: colorScheme.primary), // Themed icon color
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface), // Themed label text
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline
                    .alphabetic, // Align baseline for value and unit
                children: [
                  Text(
                    value,
                    //     style: textTheme.headline6?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface), // Themed and larger value text
                  ),
                  if (unit != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(unit,
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(
                                  0.7))), // Themed unit text, muted
                    ),
                ],
              ),
              if (isPercentage &&
                  currentValue != null &&
                  maxValue != null &&
                  maxValue > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 8.0), // Add some spacing above progress bar
                  child: LinearProgressIndicator(
                    // Styled Progress bar
                    value: currentValue / maxValue,
                    backgroundColor:
                        colorScheme.surfaceVariant, // Themed background color
                    color: colorScheme.primary, // Themed progress color
                    minHeight: 6, // Make progress bar a bit thicker
                    borderRadius:
                        BorderRadius.circular(3), // Rounded progress bar
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
