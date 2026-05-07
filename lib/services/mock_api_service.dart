// lib/services/mock_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class MockAPIService {
  // 🔴 IMPORTANT: We'll replace this URL in Step 4
  static const String _mockApiUrl = 'https://api.npoint.io/48ffe7efc76b76f1c5df';

  // Search products by name
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    print('🔍 Searching for: "$query"');

    try {
      // Simulate network delay (looks realistic)
      await Future.delayed(const Duration(milliseconds: 800));

      // Fetch all mock products
      final response = await http.get(Uri.parse(_mockApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final allItems = List<Map<String, dynamic>>.from(data['items']);

        // If search is empty, return all items
        if (query.trim().isEmpty) {
          print('✅ Returning all ${allItems.length} items');
          return allItems;
        }

        // Filter based on search query
        final queryLower = query.toLowerCase();
        final filteredItems = allItems.where((item) {
          final title = item['title']?.toLowerCase() ?? '';
          final brand = item['brand']?.toLowerCase() ?? '';
          final category = item['category']?.toLowerCase() ?? '';

          return title.contains(queryLower) ||
              brand.contains(queryLower) ||
              category.contains(queryLower);
        }).toList();

        print('✅ Found ${filteredItems.length} items matching "$query"');
        return filteredItems;
      }

      print('⚠️ Failed to fetch data');
      return [];
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  // In mock_api_service.dart, replace the lookupBarcode method with this:

// Lookup product by barcode (NOW USING API DATA)
  Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    print('🔍 Looking up barcode: $barcode');

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final response = await http.get(Uri.parse(_mockApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final allItems = List<Map<String, dynamic>>.from(data['items']);

        // Find item with matching barcode
        for (var item in allItems) {
          if (item['barcode'] == barcode) {
            print('✅ Found product: ${item['title']} for barcode: $barcode');
            return item;
          }
        }

        print('❌ No product found for barcode: $barcode');
        return null;
      }

      return null;
    } catch (e) {
      print('❌ Barcode lookup error: $e');
      return null;
    }
  }

  // Get remaining API calls (always returns plenty for mock)
  int getRemainingCalls() {
    return 999; // Unlimited!
  }

  // Map API category to your app's categories
  static String mapCategory(String apiCategory) {
    if (apiCategory.isEmpty) return 'Other';

    final cat = apiCategory.toLowerCase();

    if (cat.contains('electronic') ||
        cat.contains('computer') ||
        cat.contains('mouse')) {
      return 'Electronics';
    }

    if (cat.contains('furniture') ||
        cat.contains('chair')) {
      return 'Furniture';
    }

    if (cat.contains('kitchen') ||
        cat.contains('bottle') ||
        cat.contains('home')) {
      return 'Food & Beverages';
    }

    if (cat.contains('clothing') ||
        cat.contains('backpack') ||
        cat.contains('accessories')) {
      return 'Clothing';
    }

    return 'Other';
  }

  // Format price from API
  static double parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  // Extract product data for your Add/Edit form
  static Map<String, dynamic> extractProductData(Map<String, dynamic> apiProduct) {
    double price = 0.0;
    if (apiProduct['lowest_recorded_price'] != null) {
      price = parsePrice(apiProduct['lowest_recorded_price']);
    }

    String description = apiProduct['description'] ?? '';
    if (description.isEmpty) {
      description = apiProduct['title'] ?? 'No description available';
    }

    String? imageUrl;
    if (apiProduct['images'] != null && apiProduct['images'].isNotEmpty) {
      imageUrl = apiProduct['images'][0];
    }

    return {
      'name': apiProduct['title'] ?? 'Unknown Product',
      'description': description,
      'category': mapCategory(apiProduct['category'] ?? ''),
      'price': price,
      'barcode': apiProduct['ean'] ?? apiProduct['upc'] ?? '',
      'brand': apiProduct['brand'] ?? '',
      'model': apiProduct['model'] ?? '',
      'image_url': imageUrl,
    };
  }
}