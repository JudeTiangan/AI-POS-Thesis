import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/category.dart' as models;
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/widgets/product_image_widget.dart';

class ManageItemsScreen extends StatefulWidget {
  const ManageItemsScreen({super.key});

  @override
  State<ManageItemsScreen> createState() => _ManageItemsScreenState();
}

class _ManageItemsScreenState extends State<ManageItemsScreen> {
  final ItemService _itemService = ItemService();
  final CategoryService _categoryService = CategoryService();
  
  late Future<List<Item>> _itemsFuture;
  late Future<List<models.Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureBuilderKey = UniqueKey(); // Force rebuild
      _itemsFuture = _itemService.getItems();
      _categoriesFuture = _categoryService.getCategories();
    });
  }

  // Add a key to force FutureBuilder rebuild
  Key _futureBuilderKey = UniqueKey();

  Widget _buildItemImage(String? imageUrl) {
    // 🔍 DEBUG: Log image URL for troubleshooting
    print('🖼️ _buildItemImage called for: ${imageUrl ?? "NULL"}');
    if (imageUrl != null && imageUrl.isNotEmpty) {
      print('   ✅ Has image URL: ${imageUrl.substring(0, 50)}...');
    } else {
      print('   ❌ No image URL provided');
    }
    
    return ProductThumbnail(
      imageUrl: imageUrl,
      size: 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Items')),
      body: FutureBuilder<List<Item>>(
        key: _futureBuilderKey,
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No items found.'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: _buildItemImage(item.imageUrl),
                title: Text(item.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₱${item.price.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isOutOfStock 
                                ? Colors.red 
                                : item.isLowStock 
                                    ? Colors.orange 
                                    : Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stock: ${item.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (item.isLowStock) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.warning, color: Colors.orange, size: 16),
                          const Text(' Low Stock', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        ],
                        if (item.isOutOfStock) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const Text(' Out of Stock', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showItemDialog(item: item)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteItem(item.id!)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _deleteItem(String id) async {
    try {
      await _itemService.deleteItem(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
      _loadData(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
    }
  }

  void _showItemDialog({Item? item}) async {
    // Await the categories future before showing the dialog
    final categories = await _categoriesFuture;
    if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot add item: No categories found. Please add a category first.')));
        return;
    }
    
    showDialog(
      context: context,
      // Use a stateful builder to manage the dialog's own state, like the selected image
      builder: (context) => _ItemDialog(
        item: item,
        categories: categories,
        itemService: _itemService,
        onSave: _loadData, // Pass a callback to refresh the list on save
      ),
    );
  }
}


// A separate StatefulWidget for the Dialog to manage its own complex state
class _ItemDialog extends StatefulWidget {
  final Item? item;
  final List<models.Category> categories;
  final ItemService itemService;
  final VoidCallback onSave;

  const _ItemDialog({this.item, required this.categories, required this.itemService, required this.onSave});

  @override
  __ItemDialogState createState() => __ItemDialogState();
}

class __ItemDialogState extends State<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  String? _selectedCategoryId;
  File? _imageFile;
  XFile? _webImageFile; // For web compatibility

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '');
    _selectedCategoryId = widget.item?.categoryId;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _webImageFile = pickedFile; // Store XFile for web compatibility
        if (!kIsWeb) {
          _imageFile = File(pickedFile.path); // Only create File on non-web platforms
        }
      });
    }
  }

  // Web-compatible image widget
  Widget _buildSelectedImageWidget() {
    if (_webImageFile == null && _imageFile == null) {
      // Show existing image or placeholder
      return widget.item?.imageUrl != null && widget.item!.imageUrl!.isNotEmpty
          ? _buildDialogImage(widget.item!.imageUrl!)
          : Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.image));
    }

    // Show selected image - web compatible
    if (kIsWeb && _webImageFile != null) {
      return FutureBuilder<Uint8List>(
        future: _webImageFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            );
          }
          return Container(
            height: 100,
            width: 100,
            color: Colors.grey[200],
            child: const CircularProgressIndicator(),
          );
        },
      );
    } else if (_imageFile != null) {
      // Mobile/Desktop - use File
      return Image.file(_imageFile!, height: 100);
    }
    
    return Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.image));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Item' : 'Add Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectedImageWidget(),
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Select Image'),
                onPressed: _pickImage,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty || double.tryParse(value) == null ? 'Please enter a valid price' : null,
              ),
               TextFormField(
                                 controller: _quantityController,
                 decoration: const InputDecoration(labelText: 'Quantity'),
                 keyboardType: TextInputType.number,
                 validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Please enter a valid quantity' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories.map((models.Category category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final isEditing = widget.item != null;
              
                              final item = Item(
                  id: widget.item?.id,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  price: double.parse(_priceController.text),
                  quantity: int.parse(_quantityController.text),
                  categoryId: _selectedCategoryId!,
                  imageUrl: widget.item?.imageUrl,
                );

              try {
                if (isEditing) {
                  print('DEBUG: Updating existing item...');
                  // Pass the appropriate file based on platform
                  if (kIsWeb && _webImageFile != null) {
                    await widget.itemService.updateItem(
                      id: item.id!, 
                      item: item, 
                      webImageFile: _webImageFile
                    );
                  } else {
                    await widget.itemService.updateItem(
                      id: item.id!, 
                      item: item, 
                      imageFile: _imageFile
                    );
                  }
                } else {
                  print('DEBUG: Adding new item...');
                  // Pass the appropriate file based on platform
                  if (kIsWeb && _webImageFile != null) {
                    await widget.itemService.addItem(
                      item: item, 
                      webImageFile: _webImageFile
                    );
                  } else {
                    await widget.itemService.addItem(
                      item: item, 
                      imageFile: _imageFile
                    );
                  }
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item saved successfully!'), backgroundColor: Colors.green)
                );
                widget.onSave(); // Call the callback to refresh the list
              } catch (e) {
                print('DEBUG: Error saving item: $e');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save item: $e')));
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildDialogImage(String? imageUrl) {
    return ProductImageDisplay(
      imageUrl: imageUrl,
      width: 100,
      height: 100,
    );
  }
} 