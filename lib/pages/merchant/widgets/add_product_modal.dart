// 📄 lib/pages/merchant/widgets/add_product_modal.dart - CORRIGÉ POUR IMAGES
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../services/product_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/product_model.dart';

class AddProductModal extends StatefulWidget {
  final String shopId;
  final VoidCallback? onProductAdded;
  final Product? productToEdit;

  const AddProductModal({
    Key? key,
    required this.shopId,
    this.onProductAdded,
    this.productToEdit,
  }) : super(key: key);

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _videoUrlController = TextEditingController();
  
  String? _selectedCategory;
  List<File> _selectedImages = [];
  File? _selectedVideo;
  bool _publishNow = true;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // ✅ Variables pour la modification - CORRIGÉES
  bool get _isEditMode => widget.productToEdit != null;
  List<String> _existingImageUrls = []; // Images actuellement sur le serveur
  List<String> _originalImageUrls = []; // Images originales (pour comparaison)
  List<String> _imagesToDelete = []; // Images à supprimer du serveur

  final List<String> _categories = [
    'Électronique',
    'Mode & Vêtements',
    'Maison & Jardin',
    'Santé & Beauté',
    'Sports & Loisirs',
    'Automobile',
    'Livres & Médias',
    'Alimentation',
    'Bijoux & Accessoires',
    'Jouets & Enfants',
    'Art & Artisanat',
    'Autres',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFormForEditing();
  }

  // ✅ INITIALISATION CORRIGÉE
  void _initializeFormForEditing() {
    if (_isEditMode && widget.productToEdit != null) {
      final product = widget.productToEdit!;
      
      // Pré-remplir les champs
      _nameController.text = product.name ?? '';
      _descriptionController.text = product.description ?? '';
      _priceController.text = product.price?.toString() ?? '0';
      _stockController.text = product.stock?.toString() ?? '0';
      _videoUrlController.text = product.videoUrl ?? '';
      _selectedCategory = product.category;
      
      // Déterminer le statut de publication
      _publishNow = (product.status?.toLowerCase() ?? 'draft') == 'published';
      
      // ✅ CORRECTION: Sauvegarder les images originales ET actuelles
      final imageUrls = product.images?.map((img) => img.imageUrl ?? '').where((url) => url.isNotEmpty).toList() ?? [];
      _existingImageUrls = List.from(imageUrls); // Images actuelles (modifiables)
      _originalImageUrls = List.from(imageUrls); // Images originales (référence)
      
      print('🔧 Mode édition initialisé pour: ${product.name ?? "Produit"}');
      print('📸 Images originales: ${_originalImageUrls.length}');
      print('📸 Images actuelles: ${_existingImageUrls.length}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildForm()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditMode ? Icons.edit : Icons.add_shopping_cart,
              color: AppColors.primaryOrange,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            _isEditMode ? 'Modifier le produit' : 'Ajouter un produit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close, color: Color(0xFF6B7280), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nom du produit',
              hint: 'Ex: Smartphone Galaxy S22',
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le nom du produit est requis';
                }
                if (value.trim().length < 3) {
                  return 'Le nom doit contenir au moins 3 caractères';
                }
                return null;
              },
            ),
            
            SizedBox(height: 20),
            
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Décrivez votre produit en détail...',
              required: true,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La description est requise';
                }
                if (value.trim().length < 20) {
                  return 'La description doit contenir au moins 20 caractères';
                }
                return null;
              },
            ),
            
            SizedBox(height: 20),
            _buildCategoryDropdown(),
            SizedBox(height: 20),
            
            // ✅ SECTION IMAGES CORRIGÉE
            _buildImageSection(),
            
            SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'Prix (FCFA)',
                    hint: 'Ex: 15000',
                    required: true,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le prix est requis';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Prix invalide';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _stockController,
                    label: 'Stock disponible',
                    hint: 'Ex: 10',
                    required: true,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le stock est requis';
                      }
                      final stock = int.tryParse(value);
                      if (stock == null || stock < 0) {
                        return 'Stock invalide';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            _buildVideoSection(),
            SizedBox(height: 20),
            _buildPublishOption(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ SECTION IMAGES ENTIÈREMENT CORRIGÉE
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Images du produit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        SizedBox(height: 8),
        
        // ✅ AFFICHAGE DES IMAGES EXISTANTES (SI EN MODE ÉDITION)
        if (_isEditMode && _existingImageUrls.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library, size: 16, color: Color(0xFF0369A1)),
                    SizedBox(width: 6),
                    Text(
                      'Images actuelles (${_existingImageUrls.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildExistingImagesPreview(),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // ✅ ZONE D'AJOUT DE NOUVELLES IMAGES
        Text(
          _isEditMode ? 'Ajouter de nouvelles images:' : 'Images du produit:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedImages.isNotEmpty 
                    ? AppColors.primaryOrange 
                    : Color(0xFFE5E7EB),
                style: BorderStyle.solid,
              ),
            ),
            child: _selectedImages.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 8),
                      Text(
                        _isEditMode 
                            ? 'Ajouter de nouvelles images'
                            : 'Glissez-déposez vos images ici ou',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                      SizedBox(height: 4),
                      Text('Parcourir', style: TextStyle(fontSize: 14, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text('PNG, JPG ou WEBP (max. 5MB)', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  )
                : _buildNewImagesPreview(),
          ),
        ),
        
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text(
                '${_selectedImages.length} nouvelle(s) image(s) sélectionnée(s)',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
              ),
              Spacer(),
              GestureDetector(
                onTap: _pickImages,
                child: Text(
                  'Ajouter plus',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        
        // ✅ INDICATEUR DU TOTAL D'IMAGES
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Total: ${_existingImageUrls.length + _selectedImages.length} image(s) • ${_imagesToDelete.length > 0 ? "${_imagesToDelete.length} à supprimer" : "Aucune suppression"}',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  // ✅ APERÇU DES IMAGES EXISTANTES - CORRIGÉ
  Widget _buildExistingImagesPreview() {
    return Container(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _existingImageUrls.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _existingImageUrls[index],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[600], size: 20),
                            Text('Erreur', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeExistingImage(index),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewImagesPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeNewImage(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Annuler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(
                      _isEditMode 
                          ? (_publishNow ? 'Mettre à jour' : 'Sauvegarder')
                          : (_publishNow ? 'Publier le produit' : 'Sauvegarder'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTHODES UTILITAIRES CORRIGÉES

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection des images');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 2),
      );
      
      if (video != null) {
        setState(() => _selectedVideo = File(video.path));
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection de la vidéo');
    }
  }

  void _removeNewImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ✅ MÉTHODE CORRIGÉE: Supprimer une image existante
  void _removeExistingImage(int index) {
    final imageToDelete = _existingImageUrls[index];
    
    setState(() {
      // Retirer de la liste actuelle
      _existingImageUrls.removeAt(index);
      
      // ✅ IMPORTANT: Ajouter à la liste des images à supprimer sur le serveur
      _imagesToDelete.add(imageToDelete);
    });
    
    print('🗑️ Image marquée pour suppression: $imageToDelete');
    print('📝 Total à supprimer: ${_imagesToDelete.length}');
  }

  // ✅ SAUVEGARDE ENTIÈREMENT CORRIGÉE
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation: Au moins une image (existante ou nouvelle)
    if (_existingImageUrls.isEmpty && _selectedImages.isEmpty) {
      _showErrorSnackBar('Veuillez ajouter au moins une image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final productService = ProductService();
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        _showErrorSnackBar('Token d\'authentification manquant');
        return;
      }
      
      print('🛍️ === ${_isEditMode ? "MODIFICATION" : "CRÉATION"} PRODUIT ===');
      print('📋 Données à envoyer:');
      print('  • Nom: ${_nameController.text.trim()}');
      print('  • Catégorie: $_selectedCategory');
      print('  • Prix: ${double.parse(_priceController.text)}');
      print('  • Stock: ${int.parse(_stockController.text)}');
      print('  • Nouvelles images: ${_selectedImages.length}');
      print('  • Images conservées: ${_existingImageUrls.length}');
      print('  • Images à supprimer: ${_imagesToDelete.length}');
      print('  • Statut: ${_publishNow ? "PUBLISHED" : "DRAFT"}');
      
      if (_isEditMode) {
        // ✅ MODE MODIFICATION AVEC GESTION COMPLÈTE DES IMAGES
        final response = await productService.updateProductWithImages(
          productId: widget.productToEdit!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory!,
          price: double.parse(_priceController.text),
          stock: int.parse(_stockController.text),
          // ✅ NOUVEAUX PARAMÈTRES POUR LES IMAGES
          newImageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
          existingImageUrls: _existingImageUrls, // Images à conserver
          imagesToDelete: _imagesToDelete, // Images à supprimer
          videoUrl: _videoUrlController.text.trim().isNotEmpty 
              ? _videoUrlController.text.trim() 
              : null,
          videoFile: _selectedVideo,
          token: token,
        );

        print('✅ Réponse modification reçue: ${response.message}');

        // Mettre à jour le statut si nécessaire
        final currentStatus = (widget.productToEdit!.status ?? 'draft').toLowerCase();
        final newStatus = _publishNow ? 'published' : 'draft';
        
        if (currentStatus != newStatus) {
          await productService.updateProductStatus(
            productId: widget.productToEdit!.id,
            status: _publishNow ? 'PUBLISHED' : 'DRAFT',
            token: token,
          );
        }

        Navigator.pop(context);
        widget.onProductAdded?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Produit modifié avec succès !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // ✅ MODE CRÉATION (inchangé)
        final response = await productService.createProduct(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory!,
          price: double.parse(_priceController.text),
          stock: int.parse(_stockController.text),
          imageFiles: _selectedImages,
          videoUrl: _videoUrlController.text.trim().isNotEmpty 
              ? _videoUrlController.text.trim() 
              : null,
          videoFile: _selectedVideo,
          status: _publishNow ? 'PUBLISHED' : 'DRAFT',
          token: token,
        );

        print('✅ Réponse création reçue: ${response.success}');

        if (response.success) {
          Navigator.pop(context);
          widget.onProductAdded?.call();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _publishNow 
                    ? '🎉 Produit publié avec succès !' 
                    : '💾 Produit sauvegardé comme brouillon',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          _showErrorSnackBar(response.message);
        }
      }
      
    } catch (e) {
      print('❌ Erreur ${_isEditMode ? "modification" : "création"} produit: $e');
      
      String errorMessage = 'Une erreur est survenue';
      
      if (e is ApiError) {
        errorMessage = e.message;
        
        switch (e.code) {
          case 'NETWORK_ERROR':
            errorMessage = 'Problème de connexion. Vérifiez votre réseau.';
            break;
          case 'NO_INTERNET':
            errorMessage = 'Pas de connexion internet.';
            break;
          case 'TIMEOUT':
            errorMessage = 'La requête a pris trop de temps. Réessayez.';
            break;
          case 'FILE_SIZE_EXCEEDED':
            errorMessage = 'Un ou plusieurs fichiers sont trop volumineux.';
            break;
          case 'INVALID_FILE_TYPE':
            errorMessage = 'Format de fichier non autorisé.';
            break;
          case 'MISSING_FIELDS':
            errorMessage = 'Tous les champs requis doivent être remplis.';
            break;
          default:
            errorMessage = e.message;
        }
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Impossible de se connecter au serveur.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'La requête a pris trop de temps.';
      }
      
      _showErrorSnackBar(errorMessage);
      
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // MÉTHODES DE CONSTRUCTION (identiques, raccourcies pour la place)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            if (required) ...[SizedBox(width: 4), Text('*', style: TextStyle(color: Colors.red, fontSize: 16))],
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryOrange, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red)),
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Catégorie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            hintText: 'Sélectionnez une catégorie',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryOrange, width: 2)),
            contentPadding: EdgeInsets.all(16),
          ),
          items: _categories.map((category) => DropdownMenuItem<String>(value: category, child: Text(category))).toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          validator: (value) => value == null || value.isEmpty ? 'Veuillez sélectionner une catégorie' : null,
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vidéo du produit (optionnel)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _videoUrlController,
                decoration: InputDecoration(
                  hintText: 'URL Youtube ou autre (ex: https://youtu.be/...)',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryOrange, width: 2)),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text('OU', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: Icon(Icons.videocam, size: 16),
              label: Text('Télécharger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF3F4F6),
                foregroundColor: Color(0xFF374151),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        if (_selectedVideo != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF22C55E)),
            ),
            child: Row(
              children: [
                Icon(Icons.video_file, color: Color(0xFF22C55E)),
                SizedBox(width: 8),
                Expanded(child: Text('Vidéo sélectionnée: ${_selectedVideo!.path.split('/').last}', style: TextStyle(fontSize: 12, color: Color(0xFF15803D)))),
                GestureDetector(onTap: () => setState(() => _selectedVideo = null), child: Icon(Icons.close, color: Color(0xFF22C55E), size: 20)),
              ],
            ),
          ),
        ],
        SizedBox(height: 8),
        Text('MP4, MOV, etc. (max. 20MB)', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _buildPublishOption() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _publishNow ? AppColors.primaryOrange.withOpacity(0.1) : Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_publishNow ? Icons.publish : Icons.save, color: _publishNow ? AppColors.primaryOrange : Color(0xFFF59E0B), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Radio<bool>(value: true, groupValue: _publishNow, onChanged: (value) => setState(() => _publishNow = value!), activeColor: AppColors.primaryOrange),
                    Text(_isEditMode ? 'Publié' : 'Publier maintenant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ],
                ),
                Row(
                  children: [
                    Radio<bool>(value: false, groupValue: _publishNow, onChanged: (value) => setState(() => _publishNow = value!), activeColor: Color(0xFFF59E0B)),
                    Text(_isEditMode ? 'Brouillon' : 'Sauvegarder comme brouillon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ FONCTIONS HELPER
void showAddProductModal(BuildContext context, String shopId, {VoidCallback? onProductAdded}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddProductModal(shopId: shopId, onProductAdded: onProductAdded),
  );
}

void showEditProductModal(BuildContext context, String shopId, Product product, {VoidCallback? onProductUpdated}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddProductModal(shopId: shopId, productToEdit: product, onProductAdded: onProductUpdated),
  );
}