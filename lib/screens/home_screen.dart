import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/profile_option.dart';
import '../widgets/detail_item.dart';
import '../widgets/invitation_list_panel.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ImageService _imageService = ImageService();
  String? selectedProject;
  bool showProjectDetails = false;
  bool isDarkMode = false;
  OverlayEntry? _profileOverlayEntry;
  Uint8List? _profileImageBytes;

  Widget _buildProjectDetailsView(String projectId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar los detalles: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Detalles del proyecto no encontrados.'));
        }

        Map<String, dynamic> data =
            snapshot.data!.data() as Map<String, dynamic>;
        return _buildProjectDetails(
          data,
        ); // Llamamos a la función que construye la UI con los datos
      },
    );
  }

  final _emailController = TextEditingController();
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadProfileImage();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _deleteProject(Map<String, dynamic> projectData) async {
    if (selectedProject == null || user == null) return;

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // 1. Eliminar todas las invitaciones relacionadas con este proyecto
      final invitations =
          await FirebaseFirestore.instance
              .collection('invitations')
              .where('projectId', isEqualTo: selectedProject)
              .get();

      for (var doc in invitations.docs) {
        await doc.reference.delete();
      }

      // 2. Eliminar todas las relaciones de usuarios con este proyecto
      final projectUsers =
          await FirebaseFirestore.instance
              .collection('projectUsers')
              .where('projectId', isEqualTo: selectedProject)
              .get();

      for (var doc in projectUsers.docs) {
        await doc.reference.delete();
      }

      // 3. Eliminar el proyecto en sí
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(selectedProject)
          .delete();

      // Cerrar el diálogo de carga
      Navigator.of(context).pop();

      // Mostrar mensaje de éxito y volver a la lista
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Proyecto eliminado con éxito')));

      setState(() {
        showProjectDetails = false;
        selectedProject = null;
      });
    } catch (e) {
      // Cerrar el diálogo de carga si hay error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el proyecto: $e')),
      );
    }
  }

  // Future<bool> _isUserAdmin(String projectId) async {
  //   if (user == null) return false;

  //   final userProject = await FirebaseFirestore.instance
  //       .collection('projectUsers')
  //       .where('projectId', isEqualTo: projectId)
  //       .where('userId', isEqualTo: user!.uid)
  //       .where('role', isEqualTo: 'admin')
  //       .get();

  //   return userProject.docs.isNotEmpty;
  // }

  Future<void> _loadProfileImage() async {
    if (user == null) return;

    try {
      // Recargar el usuario actual para obtener los últimos datos
      await user?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      // Cargar imagen
      final imageBytes = await _imageService.getImage(user!.uid);

      setState(() {
        _profileImageBytes = imageBytes;
      });
    } catch (e) {
      debugPrint('Error cargando imagen y datos de usuario: $e');
    }
  }

  Future<void> _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    _saveThemePreference(isDarkMode);
  }

  String getUserName() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.displayName != null &&
        currentUser!.displayName!.isNotEmpty) {
      return currentUser.displayName!;
    } else if (currentUser?.email != null) {
      return currentUser!.email!.split('@')[0];
    }
    return 'Usuario';
  }

  void _showProfilePanel(BuildContext context) {
    _removeOverlay();
    _profileOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
            Positioned(
              right: 16,
              top: kToolbarHeight + MediaQuery.of(context).padding.top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  _profileImageBytes != null
                                      ? MemoryImage(_profileImageBytes!)
                                      : null,
                              child:
                                  _profileImageBytes == null
                                      ? Icon(Icons.person, size: 30)
                                      : null,
                              backgroundColor:
                                  isDarkMode
                                      ? Colors.blueGrey[700]
                                      : Colors.blue.shade100,
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getUserName(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  user?.email ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ProfileOption(
                        icon: Icons.settings,
                        text: "Administrar tu cuenta",
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _removeOverlay();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(),
                            ),
                          ).then((updated) {
                            if (updated == true) {
                              _loadProfileImage(); // Recargar imagen
                              setState(
                                () {},
                              ); // Forzar reconstrucción del widget
                            }
                          });
                        },
                      ),
                      Divider(height: 1),
                      ProfileOption(
                        icon: Icons.exit_to_app,
                        text: "Cerrar sesión",
                        color: Colors.red,
                        isDarkMode: isDarkMode,
                        onTap: () {
                          _removeOverlay();
                          logout(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context)?.insert(_profileOverlayEntry!);
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> projectData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar el proyecto "${projectData['name']}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteProject(projectData);
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _removeOverlay() {
    if (_profileOverlayEntry != null) {
      _profileOverlayEntry?.remove();
      _profileOverlayEntry = null;
    }
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return InvitationListPanel(
          user: user,
        ); // Widget para mostrar la lista de invitaciones
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: Text("OSCUTO"),
          actions: [
            IconButton(icon: Icon(Icons.brightness_6), onPressed: toggleTheme),
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed:
                      _showNotificationPanel, // Nueva función para mostrar el panel
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('invitations')
                          .where('userId', isEqualTo: user!.uid)
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${snapshot.data!.docs.length}',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showProfilePanel(context),
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      _profileImageBytes != null
                          ? MemoryImage(_profileImageBytes!)
                          : null,
                  child:
                      _profileImageBytes == null
                          ? Icon(Icons.person, size: 18)
                          : null,
                  backgroundColor:
                      isDarkMode ? Colors.blueGrey[700] : Colors.blue.shade100,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (showProjectDetails)
                _buildProjectDetailsView(selectedProject!)
              else
                _buildProjectList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.blueGrey[800],
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: Colors.grey[800],
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildProjectList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ElevatedButton(
              onPressed: _showCreateProjectDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor:
                    isDarkMode ? Colors.blueGrey[700] : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text("CREAR PROYECTO"),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('projectUsers')
                    .where('userId', isEqualTo: user!.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No hay proyectos disponibles.'));
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final projectUser = snapshot.data!.docs[index];
                  final projectUserData =
                      projectUser.data(); // Obtener los datos

                  if (projectUserData != null &&
                      projectUserData is Map<String, dynamic>) {
                    // Verificar que no sea nulo y sea un mapa
                    final projectId = projectUserData['projectId'];
                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .get(),
                      builder: (context, projectSnapshot) {
                        if (projectSnapshot.hasError) {
                          return Center(
                            child: Text('Error: ${projectSnapshot.error}'),
                          );
                        }

                        if (projectSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!projectSnapshot.hasData ||
                            !projectSnapshot.data!.exists) {
                          return SizedBox.shrink();
                        }

                        final projectData =
                            projectSnapshot.data!.data()
                                as Map<String, dynamic>;
                        return _buildProjectCard(
                          projectData['name'],
                          projectId,
                        );
                      },
                    );
                  } else {
                    return SizedBox.shrink(); // O un widget de error, dependiendo de tu lógica
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(String projectName, String projectId) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            selectedProject = projectId; //  Guardar el ID
            showProjectDetails = true;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            projectName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showCreateProjectDialog() {
    final _projectNameController = TextEditingController();
    final _projectDescriptionController = TextEditingController();
    final _projectTypeController = TextEditingController();
    final _workersController = TextEditingController();
    DateTime _startDate = DateTime.now();
    DateTime _endDate = DateTime.now().add(
      Duration(days: 30),
    ); //  Fecha prevista por defecto

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Crear Nuevo Proyecto'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              //  Usamos StatefulBuilder para manejar el estado dentro del diálogo
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _projectNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Proyecto',
                      ),
                    ),
                    TextField(
                      controller: _projectDescriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción del Proyecto',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value:
                          _projectTypeController.text.isNotEmpty
                              ? _projectTypeController.text
                              : null,
                      items:
                          <String>['Privada', 'Pública', 'Mixta'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _projectTypeController.text = newValue!;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Tipo de Obra'),
                    ),
                    TextField(
                      controller: _workersController,
                      decoration: InputDecoration(
                        labelText: 'Número de Trabajadores',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: Text('Fecha Inicio'),
                      subtitle: Text(
                        _startDate.toLocal().toString().split(' ')[0],
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null && pickedDate != _startDate) {
                          setState(() {
                            _startDate = pickedDate;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Fecha Fin Previsto'),
                      subtitle: Text(
                        _endDate.toLocal().toString().split(' ')[0],
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null && pickedDate != _endDate) {
                          setState(() {
                            _endDate = pickedDate;
                          });
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                String projectName = _projectNameController.text.trim();
                String projectDescription =
                    _projectDescriptionController.text.trim();
                String projectType = _projectTypeController.text.trim();
                String workers = _workersController.text.trim();

                if (projectName.isNotEmpty &&
                    projectDescription.isNotEmpty &&
                    projectType.isNotEmpty &&
                    workers.isNotEmpty) {
                  try {
                    //  1. Crear el proyecto en Firestore
                    final newProjectRef = await FirebaseFirestore.instance
                        .collection('projects')
                        .add({
                          'name': projectName,
                          'description': projectDescription,
                          'type': projectType,
                          'workers': workers,
                          'startDate': _startDate,
                          'endDate': _endDate,
                          'adminId': user!.uid,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                    final newProjectId = newProjectRef.id;

                    //  Opcional:  Agregar al administrador al proyecto con el rol "admin"
                    await FirebaseFirestore.instance
                        .collection('projectUsers')
                        .add({
                          'projectId': newProjectId,
                          'userId': user!.uid,
                          'role': 'admin',
                        });

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Proyecto creado con éxito.')),
                    );
                    setState(() {});
                  } catch (e) {
                    print('Error al crear el proyecto: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al crear el proyecto.')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor, completa todos los campos.'),
                    ),
                  );
                }
              },
              child: Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectDetails(Map<String, dynamic> projectData) {
    return Column(
      // Cambiamos ListView por Column
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    showProjectDetails = false;
                    selectedProject = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  projectData['name'] ?? "Nombre del Proyecto",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (projectData['adminId'] ==
                  user?.uid) // Solo muestra si es el administrador
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmationDialog(projectData),
                ),
            ],
          ),
        ),
        Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailItem(
                label: "Tipo de Obra:",
                value: projectData['type'] ?? "No especificado",
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 16),
              DetailItem(
                label: "Descripción:",
                value: projectData['description'] ?? "Sin descripción",
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 16),
              DetailItem(
                label: "Trabajadores:",
                value: projectData['workers'] ?? "No especificado",
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 16),
              DetailItem(
                label: "Fecha Inicio:",
                value:
                    projectData['startDate'] != null
                        ? (projectData['startDate'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .toString()
                            .split(' ')[0]
                        : "No especificada",
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 16),
              DetailItem(
                label: "Fecha Fin Prevista:",
                value:
                    projectData['endDate'] != null
                        ? (projectData['endDate'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .toString()
                            .split(' ')[0]
                        : "No especificada",
                isDarkMode: isDarkMode,
              ),
              SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(200, 50),
                    backgroundColor:
                        isDarkMode ? Colors.blueGrey[700] : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text("MÁS DETALLES"),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    "HACER REPORTE CON LA ACTUALIZAR",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.blue[200] : Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Sección para Invitar Usuarios
              Container(
                padding: EdgeInsets.all(16.0),
                margin: EdgeInsets.only(top: 24.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitar Usuario al Proyecto',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico del Usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      items:
                          ['contratista', 'supervisor'].map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Rol del Usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _inviteUser,
                      child: Text('Invitar'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50), // Agregar espacio extra al final
            ],
          ),
        ),
      ],
    );
  }

  void _inviteUser() async {
    String email = _emailController.text.trim();
    String? role = _selectedRole;

    if (email.isNotEmpty && role != null && selectedProject != null) {
      try {
        // 1. Buscar al usuario por correo electrónico
        final userSnapshot =
            await FirebaseFirestore.instance
                .collection(
                  'users',
                ) //  Asegúrate de que tu colección de usuarios se llama 'users'
                .where('email', isEqualTo: email)
                .get();

        if (userSnapshot.docs.isEmpty) {
          // 2. Manejar el caso de usuario no encontrado
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Usuario no encontrado.')));
          return; //  Detener la ejecución si el usuario no existe
        }

        //  Si llegamos aquí, el usuario existe.  Obtenemos su ID.
        final invitedUserId = userSnapshot.docs.first.id;

        //  3. Crear la invitación en la colección 'invitations'
        await FirebaseFirestore.instance.collection('invitations').add({
          'projectId': selectedProject, //  Ahora contiene el ID del proyecto
          'userId': invitedUserId,
          'role': role,
          'status': 'pending', //  Estado inicial de la invitación
          'invitedBy':
              user!.uid, // Opcional: ID del usuario que envió la invitación
          'invitedAt':
              FieldValue.serverTimestamp(), // Opcional: Fecha y hora de la invitación
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invitación enviada.')));

        //  4. Limpiar los campos después de enviar la invitación
        _emailController.clear();
        setState(() {
          _selectedRole = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la invitación: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, ingresa el correo electrónico, selecciona el rol y asegúrate de haber seleccionado un proyecto.',
          ),
        ),
      );
    }
  }
}
