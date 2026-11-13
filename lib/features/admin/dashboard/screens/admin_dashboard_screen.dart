import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../models/admin_analytics_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminDashboardControllerProvider);
    final controller = ref.read(adminDashboardControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: analyticsAsync.when(
          loading: () => const LoadingIndicator(message: 'Computing aggregate analytics...'),
          error: (err, _) => ErrorView(
            message: 'Failed to load analytics: $err',
            onRetry: () => controller.refresh(),
          ),
          data: (data) => _buildDashboardContent(context, data, theme, isDark),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    AdminAnalyticsModel data,
    ThemeData theme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 KPI Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            childAspectRatio: 1.35,
            children: [
              _buildKpiCard(
                key: const Key('admin_kpi_total_claims'),
                title: 'Total Claims',
                value: '${data.totalClaims}',
                icon: Icons.assignment_outlined,
                color: AppColors.primary,
                isDark: isDark,
                theme: theme,
              ),
              _buildKpiCard(
                key: const Key('admin_kpi_active_claims'),
                title: 'Active Claims',
                value: '${data.activeClaims}',
                icon: Icons.hourglass_top_outlined,
                color: AppColors.claimUnderReview,
                isDark: isDark,
                theme: theme,
              ),
              _buildKpiCard(
                key: const Key('admin_kpi_approval_rate'),
                title: 'Approval Rate',
                value: '${data.approvalRate.toStringAsFixed(1)}%',
                icon: Icons.verified_outlined,
                color: AppColors.success,
                isDark: isDark,
                theme: theme,
              ),
              _buildKpiCard(
                key: const Key('admin_kpi_avg_resolution'),
                title: 'Avg Resolution Time',
                value: '${data.avgResolutionDays.toStringAsFixed(1)}d',
                icon: Icons.speed,
                color: AppColors.secondary,
                isDark: isDark,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart 1: Status Breakdown Donut Pie Chart
          _buildChartContainer(
            title: 'Claims by Status Breakdown',
            isDark: isDark,
            theme: theme,
            child: SizedBox(
              key: const Key('admin_analytics_chart'),
              height: 220,
              child: _buildStatusPieChart(data.statusBreakdown, isDark),
            ),
          ),
          const SizedBox(height: 20),

          // Chart 2: Claims by Type Bar Chart
          _buildChartContainer(
            title: 'Claims by Resolution Type',
            isDark: isDark,
            theme: theme,
            child: SizedBox(
              height: 200,
              child: _buildTypeBarChart(data.claimsByType, isDark),
            ),
          ),
          const SizedBox(height: 20),

          // Chart 3: 30-Day Submissions Trend Line Chart
          _buildChartContainer(
            title: '30-Day Claim Submission Trend',
            isDark: isDark,
            theme: theme,
            child: SizedBox(
              height: 200,
              child: _buildSubmissionLineChart(data.submissionsLast30Days, isDark),
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Top Issue Categories Table
          _buildTopIssuesCard(data.topIssueCategories, isDark, theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required Key key,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(icon, color: color, size: 20.0),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required Widget child,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(Map<String, int> breakdown, bool isDark) {
    final statusColors = {
      'submitted': AppColors.claimSubmitted,
      'under_review': AppColors.claimUnderReview,
      'approved': AppColors.claimApproved,
      'rejected': AppColors.claimRejected,
      'completed': AppColors.claimCompleted,
      'draft': AppColors.claimDraft,
    };

    final total = breakdown.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Center(
        child: Text(
          'No claims data to visualize',
          style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray600),
        ),
      );
    }

    final sections = breakdown.entries.where((e) => e.value > 0).map((e) {
      final color = statusColors[e.key] ?? AppColors.primary;
      final pct = (e.value / total * 100).toStringAsFixed(0);
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        title: '$pct%',
        radius: 46,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: breakdown.entries.where((e) => e.value > 0).map((e) {
              final color = statusColors[e.key] ?? AppColors.primary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.key.replaceAll('_', ' ')} (${e.value})',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.gray400 : AppColors.gray700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBarChart(Map<String, int> types, bool isDark) {
    final typeOrder = ['warranty', 'replacement', 'refund'];
    final labels = ['Warranty', 'Replacement', 'Refund'];
    final colors = [AppColors.primary, AppColors.secondary, AppColors.tertiary];

    int maxCount = 1;
    for (final v in types.values) {
      if (v > maxCount) maxCount = v;
    }

    final barGroups = List.generate(3, (i) {
      final key = typeOrder[i];
      final val = types[key] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val.toDouble(),
            color: colors[i],
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        maxY: (maxCount + 2).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx >= 0 && idx < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      labels[idx],
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildSubmissionLineChart(List<DailySubmission> submissions, bool isDark) {
    if (submissions.isEmpty) {
      return Center(
        child: Text(
          'No submission timeline recorded',
          style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray600),
        ),
      );
    }

    final spots = List.generate(submissions.length, (i) {
      return FlSpot(i.toDouble(), submissions[i].count.toDouble());
    });

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withAlpha(30),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildTopIssuesCard(
    List<IssueCategoryMetric> categories,
    bool isDark,
    ThemeData theme,
  ) {
    final total = categories.fold(0, (a, b) => a + b.count);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Issue Categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            Text(
              'No issue categories reported yet.',
              style: TextStyle(color: isDark ? AppColors.gray400 : AppColors.gray600),
            )
          else
            ...categories.map((c) {
              final pct = total > 0 ? (c.count / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          ),
                        ),
                        Text(
                          '${c.count} (${(pct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: isDark ? AppColors.cardDark : AppColors.gray200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
