import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String name;
  final Color color; // Change the type to Color

  const CustomButton({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color, 
          ),
          child: Center(
            child: Text(name,style: const TextStyle(fontWeight: FontWeight.bold),),
          ),
        ),
      );
  }
}
