import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../services/api_service.dart';

class CatalogProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  List<StoreModel> _stores = [];

  StoreModel? _selectedStore;
  CategoryModel? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get products => _filteredProducts();
  List<CategoryModel> get categories => _categories;
  List<StoreModel> get stores => _stores;
  StoreModel? get selectedStore => _selectedStore;
  CategoryModel? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  @visibleForTesting
  bool lockCatalogForTesting = false;

  @visibleForTesting
  void setCatalogDataForTesting({
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    List<StoreModel>? stores,
    StoreModel? selectedStore,
    CategoryModel? selectedCategory,
    bool lock = true,
  }) {
    if (products != null) _products = List.from(products);
    if (categories != null) _categories = List.from(categories);
    if (stores != null) _stores = List.from(stores);
    if (selectedStore != null) _selectedStore = selectedStore;
    if (selectedCategory != null) _selectedCategory = selectedCategory;
    lockCatalogForTesting = lock;
    notifyListeners();
  }

  List<ProductModel> _filteredProducts() {
    return _products.where((p) {
      if (_selectedStore != null && p.ownerId != _selectedStore!.id) {
        return false;
      }
      if (_selectedCategory != null && p.categoryId != _selectedCategory!.id) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchCat = p.categoryName.toLowerCase().contains(q);
        final matchBarcode = p.barcode?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchCat && !matchBarcode) return false;
      }
      return true;
    }).toList();
  }

  Future<void> selectStore(StoreModel? store) async {
    if (_selectedStore?.id == store?.id) return;
    _selectedStore = store;
    _selectedCategory = null;
    if (_products.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    final targetStoreId = store?.id;

    await Future.wait([
      fetchCategories(),
      fetchProducts(),
    ]);

    if (_selectedStore?.id == targetStoreId) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(CategoryModel? category) {
    if (_selectedCategory?.id == category?.id) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadInitial() async {
    if (lockCatalogForTesting) return;
    if (_products.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    await Future.wait([
      fetchStores(),
      fetchCategories(),
      fetchProducts(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (lockCatalogForTesting) return;
    _errorMessage = null;
    await Future.wait([
      fetchStores(),
      fetchCategories(),
      fetchProducts(),
    ]);
    notifyListeners();
  }

  Future<void> fetchStores({double? lat, double? lng}) async {
    if (lockCatalogForTesting) return;
    try {
      final list = await CustomerApiService.instance.fetchStores(lat: lat, lng: lng);
      // Filter out any admin/support accounts to ensure only actual stores are listed
      _stores = list.where((s) => s.role.toLowerCase() != 'admin' && !s.email.toLowerCase().startsWith('admin@')).toList();
      if (_selectedStore != null && !_stores.any((s) => s.id == _selectedStore!.id)) {
        _selectedStore = null;
        fetchCategories();
        fetchProducts();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }


  Future<void> fetchCategories() async {
    if (lockCatalogForTesting) return;
    final storeId = _selectedStore?.id;
    try {
      final res = await CustomerApiService.instance.fetchCategories(
        storeId: storeId,
      );
      if (_selectedStore?.id == storeId) {
        _categories = res;
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> fetchProducts() async {
    if (lockCatalogForTesting) return;
    final storeId = _selectedStore?.id;
    try {
      _errorMessage = null;
      final res = await CustomerApiService.instance.fetchProducts(
        storeId: storeId,
      );
      if (_selectedStore?.id == storeId) {
        _products = res;
      }
    } catch (e) {
      if (_selectedStore?.id == storeId) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    }
  }
}
