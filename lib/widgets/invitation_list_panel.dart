import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationListPanel extends StatelessWidget {
  final User? user;

  const InvitationListPanel({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Usuario no autenticado'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invitations')
          .where('userId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Algo salió mal al cargar las invitaciones: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No tienes invitaciones pendientes.'),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = snapshot.data!.docs[index];
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            String projectId = data['projectId'];
            String invitedByUserId = data['invitedBy'];
            String role = data['role'];
            String invitationId = document.id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(invitedByUserId)
                  .get(),
              builder: (context, senderSnapshot) {
                String senderUsername = 'Cargando...';
                if (senderSnapshot.hasData && senderSnapshot.data!.exists) {
                  senderUsername = senderSnapshot.data!['username'] ?? 'Usuario desconocido';
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(projectId)
                      .get(),
                  builder: (context, projectSnapshot) {
                    String projectName = 'Cargando...';
                    if (projectSnapshot.hasData && projectSnapshot.data!.exists) {
                      projectName = projectSnapshot.data!['name'] ?? 'Nombre desconocido';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invitación al proyecto: $projectName',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Enviada por: $senderUsername'),
                            Text('Rol asignado: $role'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('invitations')
                                        .doc(invitationId)
                                        .update({'status': 'rejected'});
                                  },
                                  child: const Text(
                                    'Rechazar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('invitations')
                                        .doc(invitationId)
                                        .update({'status': 'accepted'});
                                    await FirebaseFirestore.instance
                                        .collection('projectUsers')
                                        .add({
                                          'projectId': projectId,
                                          'userId': user!.uid,
                                          'role': role,
                                          'joinedAt': FieldValue.serverTimestamp(),
                                        });
                                  },
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}