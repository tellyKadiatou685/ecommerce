// lib/pages/profile/edit_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  final User user;

  const EditProfilePage({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers pour les champs de texte
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  
  File? _selectedImage;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController(text: widget.user.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user.lastName ?? '');
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    
    // Ajouter des listeners pour détecter les changements
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {
      _hasChanges = _checkForChanges();
    });
  }

  bool _checkForChanges() {
    return _firstNameController.text != (widget.user.firstName ?? '') ||
           _lastNameController.text != (widget.user.lastName ?? '') ||
           _emailController.text != (widget.user.email ?? '') ||
           _phoneController.text != (widget.user.phone ?? '') ||
           _addressController.text != (widget.user.address ?? '') ||
           _selectedImage != null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(),
      body: _isLoading 
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primaryOrange),
          )
        : SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildPhotoSection(),
                  const SizedBox(height: 20),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 20),
                  _buildContactInfoSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // 🎯 APP BAR
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Modifier le profil',
        style: AppTextStyles.heading1.copyWith(fontSize: 18),
      ),
      backgroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.gray700),
        onPressed: () => _onBackPressed(),
      ),
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Sauver',
              style: AppTextStyles.buttonTextSecondary.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // 🎯 SECTION PHOTO DE PROFIL
  Widget _buildPhotoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // Photo de profil
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _buildProfileImage(),
                ),
              ),
              // Bouton de modification
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImagePicker,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Appuyez pour changer la photo',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 SECTION INFORMATIONS PERSONNELLES
  Widget _buildPersonalInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations personnelles',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 20),
          
          // Prénom
          _buildTextField(
            controller: _firstNameController,
            label: 'Prénom',
            icon: Icons.person_outline,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Le prénom est requis';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Nom
          _buildTextField(
            controller: _lastNameController,
            label: 'Nom',
            icon: Icons.person_outline,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Le nom est requis';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // 🎯 SECTION INFORMATIONS DE CONTACT
  Widget _buildContactInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations de contact',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 20),
          
          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'L\'email est requis';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                return 'Format d\'email invalide';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Téléphone
          _buildTextField(
            controller: _phoneController,
            label: 'Téléphone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isNotEmpty == true && value!.length < 8) {
                return 'Numéro de téléphone invalide';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Adresse
          _buildTextField(
            controller: _addressController,
            label: 'Adresse',
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // 🎯 ACTIONS DU BAS
  Widget _buildBottomActions() {
    if (!_hasChanges) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _resetChanges,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gray700,
                side: BorderSide(color: AppColors.gray300),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Annuler', style: AppTextStyles.buttonTextSecondary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Sauvegarder', style: AppTextStyles.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 WIDGETS HELPERS
  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    } else if (widget.user.avatar != null) {
      return Image.network(
        widget.user.avatar!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.orangeGradient,
      ),
      child: const Icon(
        Icons.person,
        size: 60,
        color: AppColors.white,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray300),
        ),
        filled: true,
        fillColor: AppColors.gray50,
        labelStyle: AppTextStyles.subtitle,
      ),
      style: AppTextStyles.subtitle.copyWith(color: AppColors.gray800),
    );
  }

  // 🎯 MÉTHODES FONCTIONNELLES
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir une photo',
              style: AppTextStyles.heading1.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                if (widget.user.avatar != null || _selectedImage != null)
                  _buildImagePickerOption(
                    icon: Icons.delete,
                    label: 'Supprimer',
                    color: AppColors.error,
                    onTap: _removeImage,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primaryOrange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color ?? AppColors.primaryOrange,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color ?? AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _hasChanges = true;
    });
  }

  void _resetChanges() {
    setState(() {
      _firstNameController.text = widget.user.firstName ?? '';
      _lastNameController.text = widget.user.lastName ?? '';
      _emailController.text = widget.user.email ?? '';
      _phoneController.text = widget.user.phone ?? '';
      _addressController.text = widget.user.address ?? '';
      _selectedImage = null;
      _hasChanges = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Mettre à jour le profil via AuthService
      await _authService.updateUserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        photo: _selectedImage,
      );

      // Succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Retour avec succès
      }
    } catch (e) {
      _showError('Erreur lors de la mise à jour: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onBackPressed() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Modifications non sauvegardées', style: AppTextStyles.heading1.copyWith(fontSize: 18)),
          content: Text('Voulez-vous sauvegarder vos modifications ?', style: AppTextStyles.subtitle),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fermer le dialog
                Navigator.pop(context); // Fermer la page
              },
              child: Text('Ignorer', style: AppTextStyles.buttonTextSecondary.copyWith(color: AppColors.error)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fermer le dialog
              },
              child: Text('Continuer', style: AppTextStyles.buttonTextSecondary),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fermer le dialog
                _saveProfile(); // Sauvegarder
              },
              child: Text('Sauvegarder', style: AppTextStyles.buttonTextSecondary.copyWith(color: AppColors.primaryOrange)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}