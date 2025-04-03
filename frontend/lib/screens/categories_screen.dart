import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class Category {
  final int id;
  final String name;
  final String type; // 'income' or 'expense'
  final int transactionCount;
  final int? parentId;
  final bool isPredefined;
  final List<Category> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.transactionCount,
    this.parentId,
    this.isPredefined = false,
    this.subcategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      transactionCount: json['transaction_count'] ?? 0,
      parentId: json['parent_id'],
      isPredefined: json['is_predefined'] ?? false,
      subcategories: (json['subcategories'] as List?)
              ?.map((sub) => Category.fromJson(sub))
              .toList() ??
          [],
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<Category> _categories = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedType = 'expense';
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.categoriesUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesData = json.decode(response.body);
        setState(() {
          _categories =
              categoriesData.map((data) => Category.fromJson(data)).toList();
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading categories: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCategory() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAdding = true;
      });

      try {
        final token = await _storage.read(key: 'token');
        if (token == null) {
          throw Exception('Not authenticated');
        }

        final response = await http.post(
          Uri.parse(ApiConfig.categoriesUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': _nameController.text,
            'type': _selectedType,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          setState(() {
            _categories.add(Category(
              id: data['id'],
              name: data['name'],
              type: data['type'],
              transactionCount: data['transaction_count'],
              parentId: data['parent_id'],
              isPredefined: data['is_predefined'] ?? false,
              subcategories: data['subcategories'] ?? [],
            ));
            _nameController.clear();
            _selectedType = 'expense';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Category added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'Failed to add category');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isAdding = false;
          });
        }
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.categoriesUrl}/${category.id}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Category deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting category: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editCategory(Category category) async {
    final nameController = TextEditingController(text: category.name);
    final typeController = TextEditingController(text: category.type);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Edit Category',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Category Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: typeController.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Type',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: Colors.grey[800],
              items: [
                DropdownMenuItem(
                  value: 'expense',
                  child: Text('Expense'),
                ),
                DropdownMenuItem(
                  value: 'income',
                  child: Text('Income'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  typeController.text = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a category name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final token = await _storage.read(key: 'token');
                if (token == null) {
                  throw Exception('Not authenticated');
                }

                final response = await http.put(
                  Uri.parse('${ApiConfig.categoriesUrl}/${category.id}'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'name': nameController.text,
                    'type': typeController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  _loadCategories();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final error = jsonDecode(response.body);
                  throw Exception(
                      error['detail'] ?? 'Failed to update category');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete Category',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: Colors.grey[300],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Categories',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddCategoryForm(),
                      const SizedBox(height: 24),
                      _buildCategoriesList(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAddCategoryForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Category',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Category Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a category name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Type',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: Colors.grey[900],
              items: [
                DropdownMenuItem(
                  value: 'expense',
                  child: Text('Expense'),
                ),
                DropdownMenuItem(
                  value: 'income',
                  child: Text('Income'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Add Category',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_categories.isEmpty)
          Center(
            child: Text(
              'No categories found',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isExpense = category.type == 'expense';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isExpense ? Colors.red : Colors.green)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isExpense
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            color: isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    category.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (category.isPredefined)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '(Predefined)',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '${category.transactionCount} transactions',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!category.isPredefined) ...[
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.amber),
                            onPressed: () =>
                                _showAddSubcategoryDialog(category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.amber),
                            onPressed: () => _editCategory(category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(category),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (category.subcategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: category.subcategories.length,
                        itemBuilder: (context, subIndex) {
                          final subcategory = category.subcategories[subIndex];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subcategory.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (!subcategory.isPredefined) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.amber),
                                    onPressed: () => _editCategory(subcategory),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _showDeleteConfirmation(subcategory),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  void _showAddSubcategoryDialog(Category parentCategory) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Add Subcategory to ${parentCategory.name}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Subcategory Name',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a subcategory name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final token = await _storage.read(key: 'token');
                if (token == null) {
                  throw Exception('Not authenticated');
                }

                final response = await http.post(
                  Uri.parse(ApiConfig.categoriesUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'name': nameController.text,
                    'type': parentCategory.type,
                    'parent_id': parentCategory.id,
                  }),
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  _loadCategories();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subcategory added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final error = jsonDecode(response.body);
                  throw Exception(
                      error['detail'] ?? 'Failed to add subcategory');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
