/// A class to classify receipts based on their content
class ReceiptClassifier {
  // Receipt types
  static const String retail = 'retail';
  static const String restaurant = 'restaurant';
  static const String gas = 'gas';
  static const String unknown = 'unknown';
  
  // Keywords that indicate a restaurant receipt
  static final List<String> restaurantKeywords = [
    'RESTAURANT', 'CAFE', 'DINER', 'BISTRO', 'GRILL', 'BAR', 'PUB', 'EATERY',
    'TABLE', 'SERVER', 'WAITER', 'WAITRESS', 'TIP', 'GRATUITY', 'APPETIZER',
    'ENTREE', 'DESSERT', 'MENU', 'DISH', 'MEAL', 'DINNER', 'LUNCH', 'BREAKFAST',
    'GUESTS', 'PARTY SIZE', 'RESERVATION'
  ];
  
  // Keywords that indicate a gas station receipt
  static final List<String> gasKeywords = [
    'GAS', 'FUEL', 'PETROL', 'DIESEL', 'UNLEADED', 'PREMIUM', 'REGULAR',
    'GALLONS', 'GAL', 'PUMP', 'STATION', 'OCTANE', 'LITERS', 'L',
    'SHELL', 'EXXON', 'MOBIL', 'BP', 'CHEVRON', 'TEXACO', 'CITGO', 
    'MARATHON', 'SUNOCO', 'VALERO', 'PHILLIPS', 'CONOCO', '76', 'GULF'
  ];
  
  // Keywords that indicate a retail receipt
  static final List<String> retailKeywords = [
    'STORE', 'SHOP', 'RETAIL', 'MALL', 'OUTLET', 'MARKET', 'SUPERMARKET',
    'DEPARTMENT', 'ITEM', 'PRODUCT', 'SKU', 'UPC', 'BARCODE', 'QTY', 'QUANTITY',
    'RETURN POLICY', 'EXCHANGE', 'WARRANTY', 'CASHIER', 'REGISTER', 'CHECKOUT'
  ];
  
  /// Classify a receipt based on its text content
  /// Returns the receipt type (retail, restaurant, gas, or unknown)
  static String classifyReceipt(String text) {
    final upperText = text.toUpperCase();
    
    // Count occurrences of keywords for each type
    int restaurantScore = 0;
    int gasScore = 0;
    int retailScore = 0;
    
    // Check for restaurant keywords
    for (final keyword in restaurantKeywords) {
      if (upperText.contains(keyword)) {
        restaurantScore++;
      }
    }
    
    // Check for gas station keywords
    for (final keyword in gasKeywords) {
      if (upperText.contains(keyword)) {
        gasScore++;
      }
    }
    
    // Check for retail keywords
    for (final keyword in retailKeywords) {
      if (upperText.contains(keyword)) {
        retailScore++;
      }
    }
    
    // Additional heuristics
    
    // Check for gallons or price per gallon (strong indicators of gas receipt)
    if (upperText.contains(RegExp(r'GALLONS|GAL|PRICE/GAL|PER\s+GAL'))) {
      gasScore += 3;
    }
    
    // Check for tip or gratuity (strong indicators of restaurant receipt)
    if (upperText.contains(RegExp(r'TIP|GRATUITY|SERVER|TABLE'))) {
      restaurantScore += 3;
    }
    
    // Check for item quantities (indicator of retail receipt)
    if (upperText.contains(RegExp(r'QTY|QUANTITY|ITEM\s+\d+|SKU|UPC'))) {
      retailScore += 2;
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
}
