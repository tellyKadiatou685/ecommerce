// lib/data/sample_data.dart

class SampleData {
  // Données fictives pour les boutiques
  static final List<Map<String, dynamic>> boutiques = [
    {
      'id': 1,
      'name': 'Fashion Store',
      'image': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
      'rating': 4.5,
      'products': 120,
      'category': 'Mode',
      'description': 'Boutique de mode tendance avec les dernières collections',
      'address': 'Dakar, Sénégal',
      'phone': '+221 77 123 45 67'
    },
    {
      'id': 2,
      'name': 'Tech World',
      'image': 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400',
      'rating': 4.8,
      'products': 85,
      'category': 'Électronique',
      'description': 'Spécialiste en produits électroniques et high-tech',
      'address': 'Dakar, Sénégal',
      'phone': '+221 77 234 56 78'
    },
    {
      'id': 3,
      'name': 'Beauty Corner',
      'image': 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
      'rating': 4.3,
      'products': 95,
      'category': 'Beauté',
      'description': 'Produits de beauté et cosmétiques de qualité',
      'address': 'Dakar, Sénégal',
      'phone': '+221 77 345 67 89'
    },
    {
      'id': 4,
      'name': 'Sport Plus',
      'image': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      'rating': 4.6,
      'products': 150,
      'category': 'Sport',
      'description': 'Équipements sportifs et articles de fitness',
      'address': 'Dakar, Sénégal',
      'phone': '+221 77 456 78 90'
    },
    {
      'id': 5,
      'name': 'Home Deco',
      'image': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      'rating': 4.2,
      'products': 200,
      'category': 'Maison',
      'description': 'Décoration et mobilier pour votre intérieur',
      'address': 'Dakar, Sénégal',
      'phone': '+221 77 567 89 01'
    },
  ];

  // Données fictives pour les produits
  static final List<Map<String, dynamic>> produits = [
    {
      'id': 1,
      'name': 'Sac à main élégant',
      'price': 45000,
      'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
      'likes': 24,
      'comments': 8,
      'rating': 4.5,
      'boutique': 'Fashion Store',
      'category': 'Mode',
      'description': 'Sac à main en cuir véritable, parfait pour toutes occasions',
      'stock': 15,
      'images': [
        'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
        'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=400',
      ]
    },
    {
      'id': 2,
      'name': 'Chaussures de sport',
      'price': 35000,
      'image': 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=400',
      'likes': 31,
      'comments': 12,
      'rating': 4.7,
      'boutique': 'Sport Plus',
      'category': 'Sport',
      'description': 'Chaussures de running ultra-confortables et respirantes',
      'stock': 25,
      'images': [
        'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=400',
        'https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=400',
      ]
    },
    {
      'id': 3,
      'name': 'Smartphone Pro Max',
      'price': 850000,
      'image': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400',
      'likes': 67,
      'comments': 23,
      'rating': 4.8,
      'boutique': 'Tech World',
      'category': 'Électronique',
      'description': 'Smartphone dernière génération avec appareil photo professionnel',
      'stock': 8,
      'images': [
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400',
        'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=400',
      ]
    },
    {
      'id': 4,
      'name': 'Écouteurs sans fil',
      'price': 125000,
      'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
      'likes': 42,
      'comments': 15,
      'rating': 4.6,
      'boutique': 'Tech World',
      'category': 'Électronique',
      'description': 'Écouteurs bluetooth avec réduction de bruit active',
      'stock': 20,
      'images': [
        'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
        'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400',
      ]
    },
    {
      'id': 5,
      'name': 'Rouge à lèvres mat',
      'price': 15000,
      'image': 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=400',
      'likes': 89,
      'comments': 34,
      'rating': 4.4,
      'boutique': 'Beauty Corner',
      'category': 'Beauté',
      'description': 'Rouge à lèvres longue tenue, formule hydratante',
      'stock': 50,
      'images': [
        'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=400',
        'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
      ]
    },
    {
      'id': 6,
      'name': 'Montre connectée',
      'price': 250000,
      'image': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400',
      'likes': 156,
      'comments': 67,
      'rating': 4.9,
      'boutique': 'Tech World',
      'category': 'Électronique',
      'description': 'Montre intelligente avec suivi de santé et GPS',
      'stock': 12,
      'images': [
        'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400',
        'https://images.unsplash.com/photo-1434493789847-2f02dc6ca35d?w=400',
      ]
    },
    {
      'id': 7,
      'name': 'Veste en jean',
      'price': 65000,
      'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400',
      'likes': 73,
      'comments': 21,
      'rating': 4.3,
      'boutique': 'Fashion Store',
      'category': 'Mode',
      'description': 'Veste en jean vintage, coupe moderne et confortable',
      'stock': 18,
      'images': [
        'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=400',
        'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400',
      ]
    },
    {
      'id': 8,
      'name': 'Coussin décoratif',
      'price': 22000,
      'image': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      'likes': 45,
      'comments': 18,
      'rating': 4.2,
      'boutique': 'Home Deco',
      'category': 'Maison',
      'description': 'Coussin en coton bio avec motifs géométriques',
      'stock': 30,
      'images': [
        'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400',
      ]
    },
  ];

  // Catégories disponibles
  static final List<Map<String, dynamic>> categories = [
    {
      'id': 1,
      'name': 'Mode',
      'icon': 'fashion',
      'color': '#FF6B6B',
      'image': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=300'
    },
    {
      'id': 2,
      'name': 'Électronique',
      'icon': 'electronics',
      'color': '#4ECDC4',
      'image': 'https://images.unsplash.com/photo-1468495244123-6c6c332eeece?w=300'
    },
    {
      'id': 3,
      'name': 'Beauté',
      'icon': 'beauty',
      'color': '#45B7D1',
      'image': 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=300'
    },
    {
      'id': 4,
      'name': 'Sport',
      'icon': 'sport',
      'color': '#96CEB4',
      'image': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300'
    },
    {
      'id': 5,
      'name': 'Maison',
      'icon': 'home',
      'color': '#FFEAA7',
      'image': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=300'
    },
  ];

  // Méthodes utilitaires
  static List<Map<String, dynamic>> getProductsByCategory(String category) {
    return produits.where((product) => product['category'] == category).toList();
  }

  static List<Map<String, dynamic>> getProductsByBoutique(String boutique) {
    return produits.where((product) => product['boutique'] == boutique).toList();
  }

  static Map<String, dynamic>? getBoutiqueById(int id) {
    try {
      return boutiques.firstWhere((boutique) => boutique['id'] == id);
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? getProductById(int id) {
    try {
      return produits.firstWhere((product) => product['id'] == id);
    } catch (e) {
      return null;
    }
  }

  static List<Map<String, dynamic>> searchProducts(String query) {
    if (query.isEmpty) return produits;
    
    final lowercaseQuery = query.toLowerCase();
    return produits.where((product) {
      final name = product['name'].toString().toLowerCase();
      final category = product['category'].toString().toLowerCase();
      final boutique = product['boutique'].toString().toLowerCase();
      
      return name.contains(lowercaseQuery) ||
             category.contains(lowercaseQuery) ||
             boutique.contains(lowercaseQuery);
    }).toList();
  }

  static List<Map<String, dynamic>> getFeaturedProducts() {
    // Retourne les produits avec le plus de likes
    final featured = List<Map<String, dynamic>>.from(produits);
    featured.sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
    return featured.take(4).toList();
  }

  static List<Map<String, dynamic>> getTopRatedBoutiques() {
    // Retourne les boutiques avec les meilleures notes
    final topRated = List<Map<String, dynamic>>.from(boutiques);
    topRated.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
    return topRated.take(3).toList();
  }
}