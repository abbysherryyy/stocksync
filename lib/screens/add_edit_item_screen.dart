// lib/screens/add_edit_item_screen.dart
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/database_helper.dart';

class AddEditItemScreen extends StatefulWidget {
  final Item? item;
  final bool isEditing;
  final VoidCallback? onItemSaved;
  // NEW: Add prefillData parameter
  final Map<String, dynamic>? prefillData;

  const AddEditItemScreen({
    super.key,
    this.item,
    required this.isEditing,
    this.onItemSaved,
    this.prefillData, // NEW: Accept pre-filled data from API
  });

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  // NEW: Track if data came from API
  bool _isFromApi = false;

  final List<String> _categories = [
    'Electronics',
    'Furniture',
    'Stationery',
    'Clothing',
    'Food & Beverages',
    'Office Supplies',
    'Tools & Equipment',
    'Other'
  ];

  String _selectedCategory = 'Electronics';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    // Case 1: Editing existing item
    if (widget.isEditing && widget.item != null) {
      _nameController.text = widget.item!.name;
      _selectedCategory = widget.item!.category;
      _quantityController.text = widget.item!.quantity.toString();
      _priceController.text = widget.item!.price.toStringAsFixed(2);
      _descriptionController.text = widget.item!.description ?? '';
      _isFromApi = false;
    }
    // NEW: Case 2: Pre-filled data from API
    else if (widget.prefillData != null) {
      final data = widget.prefillData!;

      _nameController.text = data['name'] ?? '';
      _selectedCategory = data['category'] ?? 'Electronics';
      _priceController.text = data['price']?.toStringAsFixed(2) ?? '0.00';
      _descriptionController.text = data['description'] ?? '';
      _quantityController.text = '1'; // Default quantity

      _isFromApi = true; // Mark as coming from API

      // Show success message that data loaded from API
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Product data loaded',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      });
    }
    // Case 3: New empty item
    else {
      _quantityController.text = '1';
      _priceController.text = '0.00';
      _isFromApi = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors in the form', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final item = Item(
        id: widget.isEditing ? widget.item!.id : null,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: widget.isEditing
            ? widget.item!.createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.isEditing) {
        await DatabaseHelper.instance.updateItem(item);
      } else {
        await DatabaseHelper.instance.createItem(item);
      }

      if (!mounted) return;

      _showSnackBar(
        '✅ "${item.name}" ${widget.isEditing ? 'updated' : 'added'} successfully!',
        Colors.green,
      );

      widget.onItemSaved?.call();
      Navigator.pop(context, true);

    } catch (e) {
      print('❌ Error saving item: $e');
      if (!mounted) return;

      setState(() => _isSaving = false);
      _showSnackBar('❌ Error: ${e.toString()}', Colors.red);
    }
  }

  double get _totalValue {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return quantity * price;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Item' : 'Add New Item',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        // NEW: Show API badge if data came from API
        actions: [
          if (_isFromApi && !widget.isEditing)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'API',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteItem,
              tooltip: 'Delete Item',
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEW: API Data Banner
                if (_isFromApi && !widget.isEditing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_done,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data loaded from API',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You can edit any fields before saving',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildTextField(
                  controller: _nameController,
                  label: 'Item Name *',
                  hintText: 'Enter item name',
                  icon: Icons.inventory,
                  validator: _validateRequired,
                ),
                const SizedBox(height: 20),

                _buildCategoryDropdown(),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _quantityController,
                        label: 'Quantity *',
                        hintText: '0',
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setState(() {}),
                        validator: _validateQuantity,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: 'Price (RM) *',
                        hintText: '0.00',
                        icon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => setState(() {}),
                        validator: _validatePrice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTotalValueCard(),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Additional details (optional)',
                  icon: Icons.description,
                  maxLines: 4,
                ),
                const SizedBox(height: 30),

                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            items: _categories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedCategory = newValue);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalValueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Quantity × Price',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Text(
            'RM ${_totalValue.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _totalValue > 0 ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isSaving
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Saving...'),
          ],
        )
            : Text(
          widget.isEditing ? 'Update Item' : 'Add to Inventory',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem() async {
    if (widget.item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${widget.item!.name}"? This cannot be undone.'),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteItem(widget.item!.id!);
        if (!mounted) return;

        _showSnackBar('✅ "${widget.item!.name}" deleted', Colors.green);
        widget.onItemSaved?.call();
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('❌ Error deleting item: $e', Colors.red);
      }
    }
  }

  // Helper methods
  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }
    final int? quantity = int.tryParse(value);
    if (quantity == null || quantity < 0) {
      return 'Enter a valid number';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    final double? price = double.tryParse(value);
    if (price == null || price < 0) {
      return 'Enter a valid price';
    }
    return null;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}