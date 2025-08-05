import 'package:flutter/material.dart';

class ComparaisonScreen extends StatefulWidget {
  const ComparaisonScreen({super.key});

  @override
  State<ComparaisonScreen> createState() => _ComparaisonScreenState();
}

class _ComparaisonScreenState extends State<ComparaisonScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer'),
      ),
      body: const Center(
        child: Text('Comparer'),
      ),
    );
  }
}