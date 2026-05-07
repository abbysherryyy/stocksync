import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // ADDED for sharing
import '../services/database_helper.dart';
import '../models/item.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Item> _items = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _dbHelper.getAllItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading items for reports: $e');
    }
  }

  // NEW: Share report feature
  Future<void> _shareReport() async {
    final stats = _stats;
    final currencyFormat = NumberFormat.currency(symbol: 'RM ');

    // Build report text using StringBuffer (mutable)
    final reportBuffer = StringBuffer();

    reportBuffer.writeln('📊 STOCKSYNC INVENTORY REPORT');
    reportBuffer.writeln('═══════════════════════════════');
    reportBuffer.writeln('Generated: ${DateTime.now().toString().substring(0, 16)}');
    reportBuffer.writeln('');
    reportBuffer.writeln('📦 OVERVIEW');
    reportBuffer.writeln('───────────');
    reportBuffer.writeln('Total Items: ${stats['totalItems']}');
    reportBuffer.writeln('Total Value: ${currencyFormat.format(stats['totalValue'])}');
    reportBuffer.writeln('Average Value: ${currencyFormat.format(stats['averagePrice'])}');
    reportBuffer.writeln('Low Stock Items: ${stats['lowStock']}');
    reportBuffer.writeln('Out of Stock: ${stats['outOfStock']}');
    reportBuffer.writeln('');
    reportBuffer.writeln('🏆 TOP 5 ITEMS');
    reportBuffer.writeln('──────────────');

    // Add top items
    final topItems = stats['topItems'] as List<dynamic>;
    if (topItems.isEmpty) {
      reportBuffer.writeln('No top items yet');
    } else {
      for (var i = 0; i < topItems.length; i++) {
        final itemData = topItems[i] as Map<String, dynamic>;
        final item = itemData['item'] as Item;
        final value = itemData['totalValue'] as double;
        reportBuffer.writeln('${i + 1}. ${item.name}');
        reportBuffer.writeln('   • ${item.quantity} × ${currencyFormat.format(item.price)} = ${currencyFormat.format(value)}');
        reportBuffer.writeln('   • Category: ${item.category}');
      }
    }

    // Add categories summary
    reportBuffer.writeln('');
    reportBuffer.writeln('📊 CATEGORY DISTRIBUTION');
    reportBuffer.writeln('────────────────────────');

    final categoryData = stats['categoryDistribution'] as Map<String, double>;
    if (categoryData.isEmpty) {
      reportBuffer.writeln('No category data');
    } else {
      categoryData.forEach((category, value) {
        final percentage = (value / (stats['totalValue'] as double) * 100).toStringAsFixed(1);
        reportBuffer.writeln('• $category: ${currencyFormat.format(value)} ($percentage%)');
      });
    }

    reportBuffer.writeln('');
    reportBuffer.writeln('────────────────────────');
    reportBuffer.writeln('via StockSync Inventory App');

    // Share the report
    await Share.share(reportBuffer.toString(), subject: 'Inventory Report');

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report shared successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Calculate statistics
  Map<String, dynamic> get _stats {
    final totalItems = _items.length;
    final totalValue = _items.fold<double>(
        0, (sum, item) => sum + (item.price * item.quantity));
    final lowStockItems = _items.where((item) => item.quantity < 5).length;
    final outOfStockItems = _items.where((item) => item.quantity == 0).length;
    final averagePrice = totalItems > 0 ? totalValue / totalItems : 0;

    // Calculate category distribution
    final categoryMap = <String, double>{};
    for (var item in _items) {
      final value = item.price * item.quantity;
      categoryMap.update(
        item.category,
            (existing) => existing + value,
        ifAbsent: () => value,
      );
    }

    // Get top 5 most valuable items
    final itemsWithValue = _items.map((item) {
      return {
        'item': item,
        'totalValue': item.price * item.quantity,
      };
    }).toList();

    itemsWithValue.sort((a, b) {
      final valueA = (a['totalValue'] as num).toDouble();
      final valueB = (b['totalValue'] as num).toDouble();
      return valueB.compareTo(valueA);
    });

    final topItems = itemsWithValue.take(5).toList();

    return {
      'totalItems': totalItems,
      'totalValue': totalValue,
      'lowStock': lowStockItems,
      'outOfStock': outOfStockItems,
      'averagePrice': averagePrice,
      'categoryDistribution': categoryMap,
      'topItems': topItems,
    };
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (index + 1)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    final stats = _stats;
    final categoryData = stats['categoryDistribution'] as Map<String, double>;
    final totalValue = stats['totalValue'] as double;
    final averagePrice = stats['averagePrice'] as double;

    // CHANGED: Updated currency formatter to RM
    final currencyFormat = NumberFormat.currency(symbol: 'RM ');

    if (categoryData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.pie_chart_outline, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Category Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to see category distribution',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pie_chart, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Category Distribution',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${sortedCategories.length} categories',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),

          const SizedBox(height: 24),
          ...sortedCategories.map((entry) {
            final percentage = totalValue > 0 ? (entry.value / totalValue * 100) : 0;
            final color = _getCategoryColor(entry.key);

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOut,
                          height: 12,
                          width: MediaQuery.of(context).size.width * (percentage / 100) * 0.7.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color,
                                color.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            // CHANGED to RM
                            Text(
                              currencyFormat.format(entry.value),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.inventory, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              averagePrice > 0
                                  ? '${(entry.value / averagePrice).toStringAsFixed(0)} items'
                                  : '0 items',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopItems() {
    final stats = _stats;
    final topItems = stats['topItems'] as List<dynamic>;

    // CHANGED: Updated currency formatter to RM
    final currencyFormat = NumberFormat.currency(symbol: 'RM ');

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Top 5 Most Valuable Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height:8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Ranking',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ),

          const SizedBox(height: 24),
          if (topItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.star_outline, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No Top Items Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add valuable items to see rankings',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            ...topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final itemData = entry.value as Map<String, dynamic>;
              final item = itemData['item'] as Item;
              final value = itemData['totalValue'] as double;
              final color = _getCategoryColor(item.category);

              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value * (index + 1)),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // CHANGED to RM
                          Text(
                            currencyFormat.format(value),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.inventory, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${item.quantity} units',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStockAnalysis() {
    final stats = _stats;
    final totalItems = stats['totalItems'] as int;
    final lowStock = stats['lowStock'] as int;
    final outOfStock = stats['outOfStock'] as int;
    final wellStocked = totalItems - lowStock - outOfStock;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Stock Level Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalItems} total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stock Level Progress Bars with animations
          _buildAnimatedStockLevelBar('Out of Stock', outOfStock, totalItems, Colors.red, 0),
          const SizedBox(height: 20),
          _buildAnimatedStockLevelBar('Low Stock (<5)', lowStock, totalItems, Colors.orange, 1),
          const SizedBox(height: 20),
          _buildAnimatedStockLevelBar('Well Stocked', wellStocked, totalItems, Colors.green, 2),

          const SizedBox(height: 24),

          // Summary Cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnimatedStockSummaryItem('Total', totalItems.toString(), Icons.inventory, Colors.blue, 0),
                _buildAnimatedStockSummaryItem('Low', lowStock.toString(), Icons.warning, Colors.orange, 1),
                _buildAnimatedStockSummaryItem('Out', outOfStock.toString(), Icons.error_outline, Colors.red, 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStockLevelBar(String label, int count, int total, Color color, int index) {
    final percentage = total > 0 ? (count / total * 100) : 0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (index + 1)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '$count items (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutQuart,
                height: 14,
                width: total > 0
                    ? MediaQuery.of(context).size.width * (count / total) * 0.8
                    : 0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStockSummaryItem(String label, String value, IconData icon, Color color, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (index + 1)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Electronics': Colors.blue,
      'Furniture': Colors.brown,
      'Stationery': Colors.purple,
      'Clothing': Colors.pink,
      'Food & Beverages': Colors.green,
      'Office Supplies': Colors.orange,
      'Tools & Equipment': Colors.deepOrange,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    // CHANGED: Updated currency formatter to RM
    final currencyFormat = NumberFormat.currency(symbol: 'RM ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        // ADDED: Share button in app bar
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            onPressed: _shareReport,
            tooltip: 'Share Report',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading Reports...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadItems,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade50,
                      Colors.purple.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.analytics,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventory Reports',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // CHANGED to RM
                          Text(
                            '${stats['totalItems']} items • ${currencyFormat.format(stats['totalValue'])} total value',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Key Metrics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildMetricCard(
                    'Total Value',
                    currencyFormat.format(stats['totalValue']),
                    Icons.attach_money,
                    Colors.green,
                    '${stats['totalItems']} items',
                    0,
                  ),
                  _buildMetricCard(
                    'Average Value',
                    currencyFormat.format(stats['averagePrice']),
                    Icons.assessment,
                    Colors.blue,
                    'Per item',
                    1,
                  ),
                  _buildMetricCard(
                    'Low Stock',
                    stats['lowStock'].toString(),
                    Icons.warning,
                    Colors.orange,
                    'Below 5 units',
                    2,
                  ),
                  _buildMetricCard(
                    'Out of Stock',
                    stats['outOfStock'].toString(),
                    Icons.error_outline,
                    Colors.red,
                    'Zero quantity',
                    3,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category Distribution
              _buildCategoryDistribution(),
              const SizedBox(height: 24),

              // Top Items
              _buildTopItems(),
              const SizedBox(height: 24),

              // Stock Analysis
              _buildStockAnalysis(),
              const SizedBox(height: 24),

              // REMOVED: Export Section (was fake feature)

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}