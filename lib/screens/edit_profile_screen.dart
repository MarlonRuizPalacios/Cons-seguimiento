import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../widgets/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  final ImageService _imageService = ImageService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _newEmailController;
  File? _imageFile;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;
  bool _showPasswordSection = false;
  bool _showEmailSection = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _newEmailController = TextEditingController();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final imageBytes = await _imageService.getImage(user!.uid);
      if (imageBytes != null) {
        setState(() => _profileImageBytes = imageBytes);
      }
    } catch (e) {
      debugPrint('Error cargando imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la imagen de perfil')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Detectar versión de Android
      final androidInfo = await _deviceInfo.androidInfo;
      final isAndroid13OrHigher = androidInfo.version.sdkInt >= 33;
      
      // 2. Seleccionar permiso correcto
      final permission = isAndroid13OrHigher ? Permission.photos : Permission.storage;
      
      // 3. Verificar estado actual
      var status = await permission.status;
      
      // 4. Mostrar explicación si es primera vez
      if (status.isDenied) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Permiso necesario"),
            content: Text("Necesitamos acceso a tus fotos para cambiar tu imagen de perfil"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Permitir"),
              ),
            ],
          ),
        );
        
        if (shouldContinue != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // 5. Solicitar permiso
      status = await permission.request();
      
      // 6. Manejar respuesta
      if (status.isGranted) {
        await _openImagePicker();
      } else if (status.isPermanentlyDenied) {
        await _showSettingsDialog();
      }
    } catch (e) {
      debugPrint('Error en selección de imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al acceder a la galería")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openImagePicker() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error en selector de imágenes: $e');
      rethrow;
    }
  }

  Future<void> _showSettingsDialog() async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Permiso requerido"),
        content: Text("Debes habilitar el permiso manualmente en configuración"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Abrir configuración"),
          ),
        ],
      ),
    );
    
    if (shouldOpen == true) {
      await openAppSettings();
    }
  }

Future<void> _updateProfile() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => _isLoading = true);
  
  try {
    String? newName;
    
    // 1. Subir nueva imagen si existe
    if (_imageFile != null) {
      final imageBytes = await _imageFile!.readAsBytes();
      await _imageService.uploadImage(user!.uid, imageBytes);
    }

    // 2. Actualizar nombre de usuario si cambió
    if (_nameController.text != user?.displayName) {
      await user?.updateDisplayName(_nameController.text);
      await user?.reload();
      newName = _nameController.text;
      
      // 3. Actualizar también en la colección 'users' de Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
            'username': _nameController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Perfil actualizado correctamente')),
    );
    
    // Aquí es donde debes colocar el pop(true) - cuando todo ha sido exitoso
    Navigator.of(context).pop(true); // Devuelve 'true' indicando que hubo cambios
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al actualizar perfil: ${e.toString()}')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Reautenticar al usuario
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPasswordController.text,
      );
      
      await user!.reauthenticateWithCredential(credential);
      
      // Actualizar contraseña
      await user!.updatePassword(_newPasswordController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
      
      setState(() {
        _showPasswordSection = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'La contraseña actual es incorrecta';
          break;
        case 'weak-password':
          errorMessage = 'La nueva contraseña es demasiado débil';
          break;
        default:
          errorMessage = 'Error al cambiar la contraseña: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Reautenticar al usuario
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPasswordController.text,
      );
      
      await user!.reauthenticateWithCredential(credential);
      
      // Actualizar email
      await user!.verifyBeforeUpdateEmail(_newEmailController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se ha enviado un enlace de verificación a tu nuevo correo')),
      );
      
      setState(() {
        _showEmailSection = false;
        _newEmailController.clear();
        _currentPasswordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'La contraseña es incorrecta';
          break;
        case 'invalid-email':
          errorMessage = 'El correo electrónico no es válido';
          break;
        case 'email-already-in-use':
          errorMessage = 'Este correo ya está en uso por otra cuenta';
          break;
        default:
          errorMessage = 'Error al cambiar el correo: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar perfil'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Sección de imagen de perfil
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : _profileImageBytes != null
                                  ? MemoryImage(_profileImageBytes!)
                                  : null,
                          child: _imageFile == null && _profileImageBytes == null
                              ? Icon(Icons.person, size: 50)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Formulario principal (nombre)
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico actual',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),

                  // Botón para cambiar contraseña
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPasswordSection = !_showPasswordSection;
                        if (_showPasswordSection) _showEmailSection = false;
                      });
                    },
                    child: Text(
                      _showPasswordSection ? 'Ocultar cambio de contraseña' : 'Cambiar contraseña',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),

                  // Sección de cambio de contraseña
                  if (_showPasswordSection) ...[
                    SizedBox(height: 16),
                    Form(
                      key: _passwordFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _currentPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Contraseña actual',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu contraseña actual';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Nueva contraseña',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa una nueva contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _updatePassword,
                            child: Text('Actualizar contraseña'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Botón para cambiar correo
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showEmailSection = !_showEmailSection;
                        if (_showEmailSection) _showPasswordSection = false;
                      });
                    },
                    child: Text(
                      _showEmailSection ? 'Ocultar cambio de correo' : 'Cambiar correo electrónico',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),

                  // Sección de cambio de correo
                  if (_showEmailSection) ...[
                    SizedBox(height: 16),
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _currentPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Contraseña actual (para verificación)',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu contraseña para verificar';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _newEmailController,
                            decoration: InputDecoration(
                              labelText: 'Nuevo correo electrónico',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa un nuevo correo';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Ingresa un correo electrónico válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _updateEmail,
                            child: Text('Actualizar correo electrónico'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Botón para guardar cambios generales
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }
}