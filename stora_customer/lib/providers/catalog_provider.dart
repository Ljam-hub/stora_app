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

  List<ProductModel> _filteredProducts() {
    return _products.where((p) {
      if (_selectedStore != null && p.ownerId != null && p.ownerId != _selectedStore!.id) {
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
    _selectedStore = store;
    _selectedCategory = null;
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      fetchCategories(),
      fetchProducts(),
    ]);

    _isLoading = false;
    notifyListeners();
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      fetchStores(),
      fetchCategories(),
      fetchProducts(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _errorMessage = null;
    await Future.wait([
      fetchStores(),
      fetchCategories(),
      fetchProducts(),
    ]);
    notifyListeners();
  }

  Future<void> fetchStores() async {
    try {
      _stores = await CustomerApiService.instance.fetchStores();
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await CustomerApiService.instance.fetchCategories(
        storeId: _selectedStore?.id,
      );
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> fetchProducts() async {
    try {
      _errorMessage = null;
      _products = await CustomerApiService.instance.fetchProducts(
        storeId: _selectedStore?.id,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
  }
}
