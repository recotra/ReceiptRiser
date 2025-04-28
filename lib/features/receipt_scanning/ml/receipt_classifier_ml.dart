import '../receipt_classifier.dart';

/// A more sophisticated receipt classifier that uses machine learning techniques
class ReceiptClassifierML {
  // Receipt types
  static const String retail = ReceiptClassifier.retail;
  static const String restaurant = ReceiptClassifier.restaurant;
  static const String gas = ReceiptClassifier.gas;
  static const String unknown = ReceiptClassifier.unknown;
  
  // Term frequency maps for each receipt type
  static final Map<String, double> _restaurantTerms = {
    'restaurant': 1.0, 'cafe': 1.0, 'diner': 1.0, 'bistro': 1.0, 'grill': 0.9, 
    'bar': 0.9, 'pub': 0.9, 'eatery': 1.0, 'table': 0.8, 'server': 0.9, 
    'waiter': 0.9, 'waitress': 0.9, 'tip': 0.9, 'gratuity': 1.0, 'appetizer': 0.8,
    'entree': 0.8, 'dessert': 0.8, 'menu': 0.7, 'dish': 0.7, 'meal': 0.7, 
    'dinner': 0.8, 'lunch': 0.8, 'breakfast': 0.8, 'guests': 0.8, 'party': 0.7,
    'reservation': 0.8, 'chef': 0.8, 'cuisine': 0.8, 'food': 0.6, 'drink': 0.6,
    'wine': 0.8, 'beer': 0.8, 'cocktail': 0.8, 'appetizers': 0.8, 'starters': 0.8,
    'main': 0.6, 'course': 0.7, 'sides': 0.7, 'beverages': 0.8, 'check': 0.7,
    'bill': 0.7, 'service': 0.6, 'charge': 0.6, 'guest': 0.8, 'order': 0.7,
    'served': 0.8, 'dining': 0.9, 'kitchen': 0.7, 'plate': 0.7, 'fork': 0.7,
    'knife': 0.7, 'spoon': 0.7, 'glass': 0.7, 'bottle': 0.6, 'cup': 0.6,
    'tablecloth': 0.8, 'napkin': 0.8, 'reservation': 0.8, 'hostess': 0.9,
    'host': 0.8, 'booth': 0.8, 'seat': 0.7, 'menu': 0.8, 'special': 0.6,
    'daily': 0.6, 'soup': 0.8, 'salad': 0.8, 'pasta': 0.8, 'steak': 0.8,
    'chicken': 0.7, 'fish': 0.7, 'vegetable': 0.7, 'bread': 0.7, 'rice': 0.7,
    'potato': 0.7, 'dessert': 0.8, 'cake': 0.8, 'ice': 0.6, 'cream': 0.6,
    'coffee': 0.7, 'tea': 0.7, 'water': 0.6, 'soda': 0.7, 'juice': 0.7,
    'milk': 0.6, 'beer': 0.8, 'wine': 0.8, 'liquor': 0.8, 'cocktail': 0.8,
    'spirit': 0.8, 'whiskey': 0.8, 'vodka': 0.8, 'rum': 0.8, 'gin': 0.8,
    'tequila': 0.8, 'brandy': 0.8, 'cognac': 0.8, 'champagne': 0.8,
    'prosecco': 0.8, 'cava': 0.8, 'sparkling': 0.7, 'red': 0.6, 'white': 0.6,
    'rose': 0.7, 'merlot': 0.8, 'cabernet': 0.8, 'chardonnay': 0.8,
    'sauvignon': 0.8, 'pinot': 0.8, 'noir': 0.8, 'grigio': 0.8, 'riesling': 0.8,
  };
  
  static final Map<String, double> _gasTerms = {
    'gas': 1.0, 'fuel': 1.0, 'petrol': 1.0, 'diesel': 1.0, 'unleaded': 0.9, 
    'premium': 0.8, 'regular': 0.8, 'gallons': 1.0, 'gal': 1.0, 'pump': 0.9, 
    'station': 0.9, 'octane': 0.9, 'liters': 0.9, 'l': 0.7, 'shell': 0.9, 
    'exxon': 0.9, 'mobil': 0.9, 'bp': 0.9, 'chevron': 0.9, 'texaco': 0.9, 
    'citgo': 0.9, 'marathon': 0.9, 'sunoco': 0.9, 'valero': 0.9, 'phillips': 0.9, 
    'conoco': 0.9, '76': 0.8, 'gulf': 0.9, 'arco': 0.9, 'amoco': 0.9,
    'gasoline': 1.0, 'petroleum': 0.9, 'filling': 0.8, 'service': 0.6,
    'self': 0.7, 'full': 0.7, 'price': 0.7, 'per': 0.7, 'gallon': 1.0,
    'liter': 0.9, 'tank': 0.8, 'fill': 0.8, 'up': 0.6, 'nozzle': 0.9,
    'hose': 0.8, 'dispenser': 0.9, 'meter': 0.8, 'reading': 0.7, 'odometer': 0.9,
    'miles': 0.8, 'km': 0.8, 'e85': 0.9, 'e15': 0.9, 'e10': 0.9, 'ethanol': 0.9,
    'biofuel': 0.9, 'propane': 0.9, 'cng': 0.9, 'lng': 0.9, 'compressed': 0.8,
    'natural': 0.7, 'liquefied': 0.8, 'hydrogen': 0.9, 'electric': 0.8,
    'charging': 0.8, 'station': 0.8, 'ev': 0.8, 'kwh': 0.9, 'kilowatt': 0.9,
    'hour': 0.7, 'refuel': 0.9, 'refill': 0.9, 'top': 0.6, 'off': 0.6,
    'convenience': 0.8, 'store': 0.7, 'car': 0.7, 'wash': 0.8, 'air': 0.7,
    'pressure': 0.7, 'tire': 0.7, 'vacuum': 0.7, 'oil': 0.8, 'change': 0.7,
    'filter': 0.7, 'windshield': 0.8, 'wiper': 0.8, 'fluid': 0.7, 'antifreeze': 0.8,
    'coolant': 0.8, 'transmission': 0.8, 'brake': 0.8, 'power': 0.7, 'steering': 0.8,
  };
  
  static final Map<String, double> _retailTerms = {
    'store': 0.9, 'shop': 0.9, 'retail': 1.0, 'mall': 0.9, 'outlet': 0.9, 
    'market': 0.8, 'supermarket': 0.9, 'department': 0.9, 'item': 0.8, 
    'product': 0.8, 'sku': 0.9, 'upc': 0.9, 'barcode': 0.9, 'qty': 0.9, 
    'quantity': 0.9, 'return': 0.8, 'policy': 0.8, 'exchange': 0.8, 
    'warranty': 0.9, 'cashier': 0.9, 'register': 0.9, 'checkout': 0.9,
    'purchase': 0.8, 'bought': 0.8, 'buy': 0.7, 'sale': 0.8, 'discount': 0.8,
    'coupon': 0.9, 'promo': 0.8, 'promotion': 0.8, 'offer': 0.7, 'special': 0.7,
    'clearance': 0.9, 'markdown': 0.9, 'price': 0.7, 'cost': 0.7, 'each': 0.8,
    'unit': 0.8, 'pack': 0.8, 'bundle': 0.8, 'set': 0.7, 'collection': 0.7,
    'brand': 0.8, 'manufacturer': 0.8, 'model': 0.8, 'style': 0.7, 'color': 0.7,
    'size': 0.7, 'weight': 0.7, 'dimensions': 0.7, 'material': 0.7, 'fabric': 0.7,
    'clothing': 0.8, 'apparel': 0.8, 'shoes': 0.8, 'accessories': 0.8,
    'jewelry': 0.8, 'watch': 0.7, 'electronics': 0.8, 'appliance': 0.8,
    'furniture': 0.8, 'home': 0.7, 'kitchen': 0.7, 'bathroom': 0.7, 'bedroom': 0.7,
    'living': 0.7, 'room': 0.7, 'outdoor': 0.7, 'garden': 0.7, 'patio': 0.7,
    'lawn': 0.7, 'tools': 0.8, 'hardware': 0.8, 'paint': 0.8, 'lumber': 0.8,
    'grocery': 0.8, 'food': 0.7, 'produce': 0.8, 'meat': 0.7, 'dairy': 0.7,
    'bakery': 0.7, 'frozen': 0.7, 'canned': 0.7, 'packaged': 0.7, 'snack': 0.7,
    'beverage': 0.7, 'health': 0.7, 'beauty': 0.7, 'personal': 0.7, 'care': 0.7,
    'pharmacy': 0.8, 'prescription': 0.8, 'medicine': 0.7, 'vitamin': 0.7,
    'supplement': 0.7, 'toy': 0.8, 'game': 0.7, 'sport': 0.7, 'fitness': 0.7,
    'outdoor': 0.7, 'recreation': 0.7, 'book': 0.8, 'magazine': 0.8, 'music': 0.7,
    'movie': 0.7, 'video': 0.7, 'gift': 0.8, 'card': 0.7, 'seasonal': 0.7,
    'holiday': 0.7, 'christmas': 0.7, 'halloween': 0.7, 'easter': 0.7,
    'valentine': 0.7, 'office': 0.8, 'school': 0.7, 'supply': 0.7, 'supplies': 0.7,
    'stationery': 0.8, 'paper': 0.7, 'pen': 0.7, 'pencil': 0.7, 'notebook': 0.7,
    'binder': 0.7, 'folder': 0.7, 'pet': 0.8, 'animal': 0.7, 'dog': 0.7,
    'cat': 0.7, 'fish': 0.7, 'bird': 0.7, 'reptile': 0.7, 'food': 0.7,
    'toy': 0.7, 'accessory': 0.7, 'cage': 0.7, 'tank': 0.7, 'bed': 0.7,
    'leash': 0.7, 'collar': 0.7, 'grooming': 0.7, 'automotive': 0.8, 'car': 0.7,
    'truck': 0.7, 'part': 0.7, 'accessory': 0.7, 'oil': 0.7, 'filter': 0.7,
    'battery': 0.7, 'tire': 0.7, 'wiper': 0.7, 'bulb': 0.7, 'floor': 0.7,
    'mat': 0.7, 'seat': 0.7, 'cover': 0.7, 'cleaning': 0.7, 'wash': 0.7,
    'wax': 0.7, 'polish': 0.7, 'protectant': 0.7, 'air': 0.7, 'freshener': 0.7,
  };
  
  /// Classify a receipt based on its text content using TF-IDF approach
  /// Returns the receipt type (retail, restaurant, gas, or unknown)
  static String classifyReceipt(String text) {
    final upperText = text.toUpperCase();
    final words = _tokenize(upperText);
    
    // Calculate scores for each receipt type
    double restaurantScore = _calculateScore(words, _restaurantTerms);
    double gasScore = _calculateScore(words, _gasTerms);
    double retailScore = _calculateScore(words, _retailTerms);
    
    // Apply additional heuristics
    
    // Strong indicators for gas receipts
    if (upperText.contains(RegExp(r'GALLONS|GAL|PRICE/GAL|PER\s+GAL'))) {
      gasScore += 5.0;
    }
    
    // Strong indicators for restaurant receipts
    if (upperText.contains(RegExp(r'TIP|GRATUITY|SERVER|TABLE'))) {
      restaurantScore += 5.0;
    }
    
    // Strong indicators for retail receipts
    if (upperText.contains(RegExp(r'QTY|QUANTITY|ITEM\s+\d+|SKU|UPC'))) {
      retailScore += 3.0;
    }
    
    // Determine the receipt type based on the highest score
    if (restaurantScore > gasScore && restaurantScore > retailScore) {
      return restaurant;
    } else if (gasScore > restaurantScore && gasScore > retailScore) {
      return gas;
    } else if (retailScore > restaurantScore && retailScore > gasScore) {
      return retail;
    } else {
      // If scores are tied or all zero, default to retail
      return retail;
    }
  }
  
  /// Calculate the score for a receipt type based on term frequency
  static double _calculateScore(List<String> words, Map<String, double> termWeights) {
    double score = 0.0;
    
    // Count occurrences of each word
    final wordCounts = <String, int>{};
    for (final word in words) {
      wordCounts[word] = (wordCounts[word] ?? 0) + 1;
    }
    
    // Calculate TF-IDF like score
    for (final entry in wordCounts.entries) {
      final word = entry.key;
      final count = entry.value;
      
      if (termWeights.containsKey(word)) {
        // Term frequency * term weight
        score += count * termWeights[word]!;
      }
    }
    
    return score;
  }
  
  /// Tokenize text into words
  static List<String> _tokenize(String text) {
    // Remove punctuation and split by whitespace
    final cleanText = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    final words = cleanText.split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.toLowerCase())
      .toList();
    
    return words;
  }
}
