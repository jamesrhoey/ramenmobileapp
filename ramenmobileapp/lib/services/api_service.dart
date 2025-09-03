import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../models/payment_method.dart';
import '../models/delivery_address.dart';
import '../config/api_config.dart';

class ApiService {
  // Dynamic base URL based on platform
  static String get baseUrl => ApiConfig.baseUrl;
  
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _authToken;

  void initialize() {
    ApiConfig.printNetworkInfo();
    print('🔗 Initializing API Service with baseUrl: $baseUrl');
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add request interceptor to include auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔐 Attempting login for user: $email');
      print('🌐 Making request to: ${_dio.options.baseUrl}/customers/login');
      
      final response = await _dio.post('/customers/login', data: {
        'email': email,
        'password': password,
      });

      print('✅ Login successful: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        _authToken = response.data['data']['token'];
        await _saveToken(_authToken!);
        return response.data;
      }
      throw Exception('Login failed');
    } on DioException catch (e) {
      print('❌ Login failed: ${e.message}');
      print('🔍 Error type: ${e.type}');
      print('🔍 Error response: ${e.response?.data}');
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> register(String firstName, String lastName, String email, String phone, String password) async {
    try {
      final response = await _dio.post('/customers/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception('Registration failed');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Menu API
  Future<List<MenuItem>> getMenuItems() async {
    try {
      final response = await _dio.get('/menu/all');
      if (response.statusCode == 200) {
        // Handle different response formats
        List<dynamic> data;
        if (response.data is Map) {
          // If response is wrapped in an object with 'data' property
          data = response.data['data'] ?? response.data['items'] ?? [];
        } else if (response.data is List) {
          // If response is directly a list
          data = response.data;
        } else {
          data = [];
        }
        return data.map((item) => MenuItem.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch menu items');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<MenuItem>> getMenuItemsByCategory(String category) async {
    try {
      final response = await _dio.get('/menu/category/$category');
      if (response.statusCode == 200) {
        List<dynamic> data;
        if (response.data is Map) {
          data = response.data['data'] ?? response.data['items'] ?? [];
        } else if (response.data is List) {
          data = response.data;
        } else {
          data = [];
        }
        return data.map((item) => MenuItem.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch menu items by category');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<MenuItem> getMenuItemById(String id) async {
    try {
      final response = await _dio.get('/menu/$id');
      if (response.statusCode == 200) {
        return MenuItem.fromJson(response.data);
      }
      throw Exception('Failed to fetch menu item');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Mobile Orders API
  Future<Order> createMobileOrder({
    required List<CartItem> items,
    required String deliveryMethod,
    String? deliveryAddress,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final orderData = {
        'items': items.map((item) => {
          'menuItem': {
            'id': item.menuItem.id ?? '1',
            'name': item.menuItem.name,
            'price': item.menuItem.price,
          },
          'quantity': item.quantity,
          'selectedAddOns': item.selectedAddOns.map((addon) => {
            'name': addon.name,
            'price': addon.price,
          }).toList(),
        }).toList(),
        'deliveryMethod': deliveryMethod,
        'deliveryAddress': deliveryAddress,
        'paymentMethod': paymentMethod,
        'notes': notes,
      };

      // Debug logging
      print('🔍 Creating mobile order with data:');
      print('📦 Items count: ${items.length}');
      print('📋 Order data: ${json.encode(orderData)}');
      print('🔑 Auth token present: ${_authToken != null ? 'Yes' : 'No'}');
      if (_authToken != null) {
        print('🔑 Auth token: ${_authToken!.substring(0, 20)}...');
      }
      
      final response = await _dio.post('/mobile-orders/add', data: orderData);
      if (response.statusCode == 201) {
        return Order.fromJson(response.data);
      }
      throw Exception('Failed to create order');
    } on DioException catch (e) {
      print('❌ Mobile order creation failed:');
      print('🔍 Status code: ${e.response?.statusCode}');
      print('🔍 Response data: ${e.response?.data}');
      print('🔍 Request data: ${e.requestOptions.data}');
      print('🔍 Request headers: ${e.requestOptions.headers}');
      throw _handleDioError(e);
    }
  }

  Future<List<Order>> getAllMobileOrders() async {
    try {
      print('🔍 Fetching mobile orders...');
      print('🔑 Auth token: ${_authToken != null ? 'Present' : 'Missing'}');
      
      final response = await _dio.get('/mobile-orders/all');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => Order.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch orders');
    } on DioException catch (e) {
      print('❌ Mobile orders fetch failed: ${e.message}');
      print('🔍 Status code: ${e.response?.statusCode}');
      print('🔍 Response data: ${e.response?.data}');
      
      // If it's an authentication error, return empty list instead of throwing
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        print('⚠️ Authentication required for mobile orders, returning empty list');
        return [];
      }
      
      throw _handleDioError(e);
    }
  }

  Future<List<Order>> getCustomerOrders() async {
    try {
      print('🔍 Fetching customer orders...');
      print('🔑 Auth token: ${_authToken != null ? 'Present' : 'Missing'}');
      
      final response = await _dio.get('/mobile-orders/my-orders');
      print('Raw API response: ${response.data}');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => Order.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch customer orders');
    } on DioException catch (e) {
      print('❌ Customer orders fetch failed: ${e.message}');
      print('🔍 Status code: ${e.response?.statusCode}');
      print('🔍 Response data: ${e.response?.data}');
      
      // If it's an authentication error, return empty list instead of throwing
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        print('⚠️ Authentication required for customer orders, returning empty list');
        return [];
      }
      
      throw _handleDioError(e);
    }
  }

  Future<Order> getMobileOrderById(String id) async {
    try {
      final response = await _dio.get('/mobile-orders/$id');
      if (response.statusCode == 200) {
        return Order.fromJson(response.data);
      }
      throw Exception('Failed to fetch order');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Order> updateMobileOrder(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.put('/mobile-orders/update/$id', data: updates);
      if (response.statusCode == 200) {
        return Order.fromJson(response.data);
      }
      throw Exception('Failed to update order');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Customer API
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final response = await _dio.get('/customers/all');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      throw Exception('Failed to fetch customers');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> customerData) async {
    try {
      final response = await _dio.post('/customers', data: customerData);
      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception('Failed to create customer');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Payment Methods API
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await _dio.get('/payment-methods/all');
      if (response.statusCode == 200) {
        List<dynamic> data;
        if (response.data is Map) {
          data = response.data['data'] ?? [];
        } else if (response.data is List) {
          data = response.data;
        } else {
          data = [];
        }
        return data.map((item) => PaymentMethod.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch payment methods');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<PaymentMethod> createPaymentMethod(PaymentMethod paymentMethod) async {
    try {
      final response = await _dio.post('/payment-methods', data: paymentMethod.toJson());
      if (response.statusCode == 201) {
        return PaymentMethod.fromJson(response.data);
      }
      throw Exception('Failed to create payment method');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<PaymentMethod> updatePaymentMethod(String id, PaymentMethod paymentMethod) async {
    try {
      final response = await _dio.put('/payment-methods/update/$id', data: paymentMethod.toJson());
      if (response.statusCode == 200) {
        return PaymentMethod.fromJson(response.data);
      }
      throw Exception('Failed to update payment method');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> deletePaymentMethod(String id) async {
    try {
      final response = await _dio.delete('/payment-methods/delete/$id');
      if (response.statusCode != 200) {
        throw Exception('Failed to delete payment method');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> createPaymentMethodFromMap(Map<String, dynamic> data) async {
    final response = await _dio.post('/payment-methods/add', data: data);
    if (response.statusCode != 201) {
      throw Exception('Failed to create payment method');
    }
  }

  // Delivery Addresses API
  Future<List<DeliveryAddress>> getDeliveryAddresses() async {
    try {
      final response = await _dio.get('/delivery-addresses/all');
      if (response.statusCode == 200) {
        List<dynamic> data;
        if (response.data is Map) {
          data = response.data['data'] ?? [];
        } else if (response.data is List) {
          data = response.data;
        } else {
          data = [];
        }
        return data.map((item) => DeliveryAddress.fromJson(item)).toList();
      }
      throw Exception('Failed to fetch delivery addresses');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<DeliveryAddress> createDeliveryAddress(DeliveryAddress address) async {
    try {
      final response = await _dio.post('/delivery-addresses', data: address.toJson());
      if (response.statusCode == 201) {
        return DeliveryAddress.fromJson(response.data);
      }
      throw Exception('Failed to create delivery address');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<DeliveryAddress> createDeliveryAddressFromMap(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/delivery-addresses/add', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        // The backend returns { success, message, data }
        final addressData = response.data['data'] ?? response.data;
        return DeliveryAddress.fromJson(addressData);
      }
      throw Exception('Failed to create delivery address');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<DeliveryAddress> updateDeliveryAddress(String id, DeliveryAddress address) async {
    try {
      final response = await _dio.put('/delivery-addresses/update/$id', data: address.toJson());
      if (response.statusCode == 200) {
        return DeliveryAddress.fromJson(response.data);
      }
      throw Exception('Failed to update delivery address');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> deleteDeliveryAddress(String id) async {
    try {
      final response = await _dio.delete('/delivery-addresses/delete/$id');
      if (response.statusCode != 200) {
        throw Exception('Failed to delete delivery address');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Token management
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    return _authToken;
  }

  Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isAuthenticated => _authToken != null;

  // Error handling
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'Server error';
        return Exception('Error $statusCode: $message');
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      default:
        return Exception('Network error: ${e.message}');
    }
  }

  // Image URL utilities
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'assets/profilesgg.png'; // Default fallback
    }
    
    // If it's already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    
    // If it's an asset path, return as is
    if (imagePath.startsWith('assets/') || imagePath.contains('assets/')) {
      return imagePath;
    }
    
    // If it's just a filename (from backend), construct the full URL
    // Backend stores only filenames like "1752799756016-997715280-ramenbg.jpg"
    final serverBaseUrl = baseUrl.replaceAll('/api/v1', '');
    return '$serverBaseUrl/uploads/menus/$imagePath';
  }

  static bool isNetworkImage(String imagePath) {
    // It's a network image if it's a full URL or a backend filename (not an asset)
    return imagePath.startsWith('http://') || imagePath.startsWith('https://') || 
           (!imagePath.startsWith('assets/') && !imagePath.contains('assets/'));
  }
} 