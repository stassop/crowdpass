import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DeveloperService {
  static Future<void> clearAppData({bool verbose = true, BuildContext? context}) async {
    void log(String message) {
      if (verbose) print('[DeveloperService]: $message');
    }
    
    log('Starting to clear app data...');

    // 1. Clear Firebase Authentication state
    try {
      await FirebaseAuth.instance.signOut();
      log('Firebase Auth signed out successfully.');
    } on FirebaseAuthException catch (e) {
      log('Error signing out Firebase Auth: $e');
    }

    // 2. Clear Firestore cache
    try {
      await FirebaseFirestore.instance.clearPersistence();
      log('Firestore cache cleared.');
    } catch (e) {
      log('Error clearing Firestore cache: $e');
    }
    
    // 3. Clear SharedPreferences
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log('SharedPreferences cleared.');
    } catch (e) {
      log('Error clearing SharedPreferences: $e');
    }

    // 4. Clear application support and temporary directories
    try {
      // Clear Application Support Directory
      Directory appSupportDir = await getApplicationSupportDirectory();
      if (appSupportDir.existsSync()) {
        await appSupportDir.delete(recursive: true);
        await appSupportDir.create(recursive: true);
        log('Application Support Directory cleared.');
      }

      // Clear Temporary Directory
      Directory tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(recursive: true);
        log('Temporary Directory cleared.');
      }
    } catch (e) {
      log('Error clearing file directories: $e');
    }
    
    // 5. Navigate to the login screen or initial state
    if (context != null) {
      log('Navigating to login screen...');
      Navigator.of(context).pushReplacementNamed('/sign_in/');
    }
    
    log('All specified app data has been cleared.');
  }
}

// IMPORTANT: Add this import to your file
// import 'package:firebase_auth/firebase_auth.dart';