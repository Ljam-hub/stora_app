import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../services/api_service.dart';

class CatalogProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  List<StoreModel> _stores = [];

  // Cached all-stores data for zero-delay switching
  List<ProductModel> _allStoresProducts = [];
  List<CategoryModel> _allStoresCategories = [];

  StoreModel? _selectedStore;
  CategoryModel? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel>? _cachedFilteredProducts;
  List<ProductModel> get products => _cachedFilteredProducts ??= _filteredProducts();
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
    _cachedFilteredProducts = null;
    notifyListeners();
  }

  List<ProductModel> _filteredProducts() {
    final filtered = _products.where((p) {
      if (_selectedStore != null && p.ownerId != _selectedStore!.id) {
        return false;
      }
      if (_selectedStore == null && _stores.isNotEmpty && !_stores.any((s) => s.id == p.ownerId)) {
        return false;
      }
      if (_selectedCategory != null) {
        if (_selectedStore == null) {
          // Cross-store match by normalized category name
          if (p.categoryName.trim().toLowerCase() != _selectedCategory!.name.trim().toLowerCase()) {
            return false;
          }
        } else if (p.categoryId != _selectedCategory!.id) {
          return false;
        }
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

    if (_selectedStore == null) {
      final Map<String, ProductModel> bestDeals = {};
      for (final p in filtered) {
        final key = p.name.toLowerCase().trim();
        if (!bestDeals.containsKey(key)) {
          bestDeals[key] = p;
        } else if (p.price < bestDeals[key]!.price) {
          bestDeals[key] = p;
        }
      }
      return bestDeals.values.toList();
    }

    return filtered;
  }

  Future<void> selectStore(StoreModel? store) async {
    if (store != null && !store.isOpen) return;
    if (_selectedStore?.id == store?.id) return;
    _selectedStore = store;
    _selectedCategory = null;
    _cachedFilteredProducts = null;

    if (store == null) {
      // Returning to All Stores: restore instantly from cache with 0ms delay!
      if (_allStoresProducts.isNotEmpty) {
        _products = List.from(_allStoresProducts);
        _categories = List.from(_allStoresCategories);
      }
      _isLoading = false;
      notifyListeners();
    } else {
      // Selecting specific store: immediately filter from cached products if available for instant feel!
      if (_allStoresProducts.isNotEmpty) {
        final storeProds = _allStoresProducts.where((p) => p.ownerId == store.id).toList();
        if (storeProds.isNotEmpty) {
          _products = storeProds;
        }
      }
      _isLoading = false;
      notifyListeners();
    }

    final targetStoreId = store?.id;

    await Future.wait([
      fetchCategories(),
      fetchProducts(),
    ]);

    if (_selectedStore?.id == targetStoreId) {
      _isLoading = false;
      _cachedFilteredProducts = null;
      notifyListeners();
    }
  }

  void selectCategory(CategoryModel? category) {
    if (_selectedCategory?.id == category?.id) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    _cachedFilteredProducts = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _cachedFilteredProducts = null;
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

    if (_selectedStore == null) {
      _allStoresProducts = List.from(_products);
      _allStoresCategories = List.from(_categories);
    }

    _isLoading = false;
    _cachedFilteredProducts = null;
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
    if (_selectedStore == null) {
      _allStoresProducts = List.from(_products);
      _allStoresCategories = List.from(_categories);
    }
    _cachedFilteredProducts = null;
    notifyListeners();
  }

  Future<void> fetchStores({double? lat, double? lng}) async {
    if (lockCatalogForTesting) return;
    try {
      final list = await CustomerApiService.instance.fetchStores(lat: lat, lng: lng);
      // Filter out admin accounts and closed stores so only open stores are visible to customers
      _stores = list.where((s) => s.isOpen && s.role.toLowerCase() != 'admin' && !s.email.toLowerCase().startsWith('admin@')).toList();
      if (_selectedStore != null && (!_selectedStore!.isOpen || !_stores.any((s) => s.id == _selectedStore!.id))) {
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
        if (storeId == null) {
          // Deduplicate categories by normalized name when viewing All Stores
          final seen = <String>{};
          final uniqueCategories = <CategoryModel>[];
          for (final cat in res) {
            final key = cat.name.trim().toLowerCase();
            if (key.isNotEmpty && seen.add(key)) {
              uniqueCategories.add(cat);
            }
          }
          _categories = uniqueCategories;
          _allStoresCategories = List.from(uniqueCategories);
        } else {
          _categories = res;
        }
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
        if (storeId == null) {
          _allStoresProducts = List.from(res);
        }
        _cachedFilteredProducts = null;
      }
    } catch (e) {
      if (_selectedStore?.id == storeId) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    }
  }
}
