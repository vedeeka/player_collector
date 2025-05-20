import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfilePage extends StatelessWidget {
  final String name;

  ProfilePage({required this.name});

  Future<Profile> fetchProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc('name').get();

    if (!doc.exists) {
      throw Exception('User not found');
    }

    final data = doc.data()!;
    return Profile(
      name: data['name'],
      email: data['email'],
     

    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<Profile>(
        future: fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final profile = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                 
                  SizedBox(height: 20),
                  Text(
                    profile.name,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    profile.email,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 20),
                  Divider(),
               
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      // Add edit profile functionality here
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      child: Text('Edit Profile', style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: StadiumBorder(),
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
}

class Profile {
  final String name;
  final String email;


  Profile({
    required this.name,
    required this.email,

  });
}
