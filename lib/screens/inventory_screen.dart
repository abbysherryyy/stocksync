import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../services/database_helper.dart';
import 'add_edit_item_screen.dart';
import 'product_search_screen.dart'; // NEW: Import for product search

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> _items = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _gridView = false;
  final Set<int> _selectedItems = {};

  // Get unique categories from items
  List<String> get _categories {
    final categories = _items.map((item) => item.category).toSet().toList();
    categories.insert(0, 'All');
    return categories;
  }

  // Calculate statistics
  Map<String, dynamic> get _stats {
    final totalItems = _filteredItems.length;
    final totalValue = _filteredItems.fold<double>(
        0, (sum, item) => sum + (item.price * item.quantity));
    final lowStockItems =
        _filteredItems.where((item) => item.quantity < 5).length;
    final outOfStockItems =
        _filteredItems.where((item) => item.quantity == 0).length;

    return {
      'totalItems': totalItems,
      'totalValue': totalValue,
      'lowStock': lowStockItems,
      'outOfStock': outOfStockItems,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (_isLoading && _items.isNotEmpty) return;

    setState(() => _isLoading = true);
    try {
      final items = await _dbHelper.getAllItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading items: $e');
    }
  }

  List<Item> get _filteredItems {
    List<Item> filtered = _items;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            (item.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((item) => item.category == _selectedCategory)
          .toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'value':
          comparison = (a.price * a.quantity).compareTo(b.price * b.quantity);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<void> _updateQuantity(Item item, int change) async {
    final newQuantity = item.quantity + change;
    if (newQuantity < 0) return;

    final updatedItem = Item(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: newQuantity,
      price: item.price,
      description: item.description,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _dbHelper.updateItem(updatedItem);

      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        setState(() {
          _items[index] = updatedItem;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name}: ${item.quantity} → $newQuantity'),
          backgroundColor: change > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  // NEW: Show add options bottom sheet
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Scan Barcode Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              ),
              title: const Text(
                'Scan Barcode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Use camera to scan product barcode'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductSearchScreen(),
                  ),
                ).then((_) {
                  _loadItems(); // Refresh when returning
                });
              },
            ),

            // Search Online Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_upload, color: Colors.green),
              ),
              title: const Text(
                'Search Online',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Find products from online database'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductSearchScreen(),
                  ),
                ).then((_) {
                  _loadItems(); // Refresh when returning
                });
              },
            ),

            // Manual Entry Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.orange),
              ),
              title: const Text(
                'Add Manually',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Enter product details yourself'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddItem(); // Your existing method
              },
            ),

            const SizedBox(height: 10),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditItemScreen(isEditing: false),
      ),
    );

    if (result == true) {
      await _loadItems();
    }
  }

  Future<void> _editItem(Item item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditItemScreen(
          item: item,
          isEditing: true,
        ),
      ),
    );

    if (result == true) {
      await _loadItems();
    }
  }

  Future<void> _deleteItem(Item item) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}"? This action cannot be undone.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteItem(item.id!);
        setState(() {
          _items.removeWhere((i) => i.id == item.id);
          _selectedItems.remove(item.id);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        print('Error deleting item: $e');
      }
    }
  }

  void _toggleItemSelection(int? itemId) {
    if (itemId == null) return;
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _selectAllItems() {
    setState(() {
      if (_selectedItems.length == _filteredItems.length) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(_filteredItems.map((item) => item.id!).toSet());
      }
    });
  }

  Future<void> _bulkUpdateQuantity(int change) async {
    for (final itemId in _selectedItems) {
      final item = _items.firstWhere((i) => i.id == itemId);
      await _updateQuantity(item, change);
    }
    setState(() => _selectedItems.clear());
  }

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Delete ${_selectedItems.length} selected items?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final itemId in _selectedItems) {
        final item = _items.firstWhere((i) => i.id == itemId);
        await _dbHelper.deleteItem(item.id!);
      }
      setState(() {
        _items.removeWhere((item) => _selectedItems.contains(item.id));
        _selectedItems.clear();
      });
    }
  }

  void _showSortFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort & Filter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Category Filter
            _buildFilterSection('Category', _categories, _selectedCategory,
                    (value) => setState(() => _selectedCategory = value)),

            const SizedBox(height: 20),

            // Sort Options
            _buildSortSection(),

            const SizedBox(height: 20),

            // View Toggle
            Row(
              children: [
                const Text('View:', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  icon: Icon(_gridView ? Icons.view_list : Icons.grid_view,
                      color: Colors.blue),
                  onPressed: () => setState(() => _gridView = !_gridView),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _sortBy = 'name';
                        _sortAscending = true;
                        _searchController.clear();
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options,
      String selectedValue, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title:', style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((category) {
            final isSelected = category == selectedValue;
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) => onChanged(category),
              backgroundColor: isSelected ? Colors.blue.shade50 : null,
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSortSection() {
    final sortOptions = [
      {'label': 'Name', 'value': 'name'},
      {'label': 'Price', 'value': 'price'},
      {'label': 'Quantity', 'value': 'quantity'},
      {'label': 'Category', 'value': 'category'},
      {'label': 'Total Value', 'value': 'value'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortOptions.map((option) {
            final isSelected = _sortBy == option['value'];
            return ChoiceChip(
              label: Text(option['label']!),
              selected: isSelected,
              onSelected: (selected) =>
                  setState(() => _sortBy = option['value']!),
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.blue),
              onPressed: () => setState(() => _sortAscending = !_sortAscending),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            Text(_sortAscending ? 'Ascending' : 'Descending'),
          ],
        ),
      ],
    );
  }

  // COMPACT Stats Card - UPDATED with RM currency
  Widget _buildStatsCard() {
    final stats = _stats;

    // Create custom formatter for RM
    String formatRM(double value) {
      return 'RM ${NumberFormat('#,##0.00', 'en_US').format(value)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Items
          _buildCompactStatItem(
            icon: Icons.inventory,
            value: stats['totalItems'].toString(),
            label: 'Items',
            color: Colors.blue,
          ),

          // Total Value - CHANGED to RM
          _buildCompactStatItem(
            icon: Icons.attach_money,
            value: formatRM(stats['totalValue']),
            label: 'Value',
            color: Colors.green,
          ),

          // Low Stock
          _buildCompactStatItem(
            icon: Icons.warning,
            value: stats['lowStock'].toString(),
            label: 'Low',
            color: Colors.orange,
          ),

          // Out of Stock
          _buildCompactStatItem(
            icon: Icons.error_outline,
            value: stats['outOfStock'].toString(),
            label: 'Out',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Item item) {
    final isSelected = _selectedItems.contains(item.id);
    final isLowStock = item.quantity < 5;
    final isOutOfStock = item.quantity == 0;
    final totalValue = item.price * item.quantity;

    // Create custom formatter for RM
    String formatRM(double value) {
      return 'RM ${NumberFormat('#,##0.00', 'en_US').format(value)}';
    }

    return GestureDetector(
      onTap: () => _editItem(item),
      onLongPress: () => _toggleItemSelection(item.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isSelected ? 0.2 : 0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isOutOfStock
                ? Colors.red.shade100
                : isLowStock
                ? Colors.orange.shade100
                : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with category and selection
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(item.category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getCategoryColor(item.category),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Item name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const Spacer(),

                  // Quantity and price row
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? Colors.red.shade50
                                      : isLowStock
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.quantity.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isOutOfStock
                                        ? Colors.red
                                        : isLowStock
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: () => _updateQuantity(item, -1),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: () => _updateQuantity(item, 1),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          // CHANGED to RM
                          Text(
                            formatRM(item.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // CHANGED to RM
                          Text(
                            'Total: ${formatRM(totalValue)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stock status badge
            if (isOutOfStock || isLowStock)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOutOfStock ? 'OUT' : 'LOW',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Item item) {
    final isSelected = _selectedItems.contains(item.id);
    final isLowStock = item.quantity < 5;
    final isOutOfStock = item.quantity == 0;

    // Create custom formatter for RM
    String formatRM(double value) {
      return 'RM ${NumberFormat('#,##0.00', 'en_US').format(value)}';
    }

    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _deleteItem(item);
          return false;
        }
        return false;
      },
      child: GestureDetector(
        onTap: () => _editItem(item),
        onLongPress: () => _toggleItemSelection(item.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(isSelected ? 0.2 : 0.1),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : (isOutOfStock
                  ? Colors.red.shade100
                  : isLowStock
                  ? Colors.orange.shade100
                  : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleItemSelection(item.id),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(item.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getCategoryColor(item.category),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OUT',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LOW',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qty: ${item.quantity}',
                            style: TextStyle(
                              color: isOutOfStock
                                  ? Colors.red
                                  : isLowStock
                                  ? Colors.orange
                                  : Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16),
                                      onPressed: () => _updateQuantity(item, -1),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16),
                                      onPressed: () => _updateQuantity(item, 1),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // CHANGED to RM
                        Text(
                          formatRM(item.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // CHANGED to RM
                        Text(
                          'Total: ${formatRM(item.price * item.quantity)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    return colors[category] ?? Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showSortFilterSheet,
            tooltip: 'Sort & Filter',
          ),
          if (_selectedItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _bulkUpdateQuantity(1),
              tooltip: 'Increase Quantity',
            ),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => _bulkUpdateQuantity(-1),
              tooltip: 'Decrease Quantity',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _bulkDelete,
              tooltip: 'Delete Selected',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
            tooltip: 'Refresh',
          ),
        ],
        bottom: _selectedItems.isNotEmpty
            ? PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Checkbox(
                  value: _selectedItems.length == filteredItems.length,
                  onChanged: (value) => _selectAllItems(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  '${_selectedItems.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedItems.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions, // UPDATED: Now shows options
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Enhanced Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items by name, category, or description...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),

          // Compact Statistics Card
          _buildStatsCard(),

          // Active Filters Bar
          if (_selectedCategory != 'All' || _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_searchQuery.isNotEmpty)
                            Chip(
                              label: Text('Search: "$_searchQuery"'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _searchController.clear(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          if (_selectedCategory != 'All')
                            Chip(
                              label: Text('Category: $_selectedCategory'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _selectedCategory = 'All'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Items Count and View Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredItems.length} ${filteredItems.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view,
                        color: _gridView ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _gridView = true),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.view_list,
                        color: !_gridView ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _gridView = false),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items List/Grid
          Expanded(
            child: _isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading inventory...'),
                ],
              ),
            )
                : filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_outlined,
                    size: 100,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _items.isEmpty
                        ? 'Your inventory is empty'
                        : 'No matching items found',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _items.isEmpty
                        ? 'Tap + to add your first item'
                        : 'Try a different search or filter',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_items.isEmpty)
                    ElevatedButton.icon(
                      onPressed: _showAddOptions,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            )
                : _gridView
                ? GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) =>
                  _buildItemCard(filteredItems[index]),
            )
                : RefreshIndicator(
              onRefresh: _loadItems,
              color: Colors.blue,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) =>
                    _buildListItem(filteredItems[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}