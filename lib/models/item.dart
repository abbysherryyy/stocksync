// models/item.dart - ENHANCED VERSION
class Item {
  final int? id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Item to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create Item from Map with error handling
  static Item fromMap(Map<String, dynamic> map) {
    try {
      return Item(
        id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
        name: map['name']?.toString() ?? 'Unknown Item',
        category: map['category']?.toString() ?? 'Other',
        quantity: map['quantity'] != null ? int.tryParse(map['quantity'].toString()) ?? 0 : 0,
        price: map['price'] != null ? double.tryParse(map['price'].toString()) ?? 0.0 : 0.0,
        description: map['description']?.toString(),
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing item from map: $e');
      print('Map data: $map');
      // Return a default item
      return Item(
        id: null,
        name: 'Error Item',
        category: 'Other',
        quantity: 0,
        price: 0.0,
        description: 'Error parsing item data',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // Helper method to create a new item with current timestamps
  static Item createNew({
    required String name,
    required String category,
    required int quantity,
    required double price,
    String? description,
  }) {
    final now = DateTime.now();
    return Item(
      name: name,
      category: category,
      quantity: quantity,
      price: price,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Copy with new values
  Item copyWith({
    int? id,
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}