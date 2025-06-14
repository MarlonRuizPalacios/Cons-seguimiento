import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

class ImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadImage(String userId, Uint8List imageBytes) async {
    try {
      final base64String = base64Encode(imageBytes);

      await _firestore.collection('user_images').doc(userId).set({
        'image': base64String,
        'timestamp': FieldValue.serverTimestamp(),
        'format': 'jpg',
        'size': imageBytes.length,
      });

      // No necesitamos actualizar photoURL en Auth ya que usamos Base64 directamente
    } catch (e) {
      print('Error al subir imagen: $e');
      rethrow;
    }
  }

  Future<Uint8List?> getImage(String userId) async {
    try {
      final doc = await _firestore.collection('user_images').doc(userId).get();

      if (doc.exists && doc.data()?['image'] != null) {
        return base64Decode(doc.data()!['image']);
      }
      return null;
    } catch (e) {
      print('Error al obtener imagen: $e');
      return null;
    }
  }
}
