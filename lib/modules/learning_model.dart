import 'package:flutter/material.dart';

class LearningModel {
  final String name;
  final String description;
  final IconData icon;

  const LearningModel({
    required this.name,
    required this.description,
    required this.icon,
  });
}

// Sample data for learning models
List<LearningModel> sampleModels = [
  const LearningModel(
    name: "Alphabet Explorer",
    description: "Learn the alphabet A-Z and how to pronounce each letter.",
    icon: Icons.abc,
  ),
  const LearningModel(
    name: "Animal Names",
    description: "Recognize animals and how to pronounce their names.",
    icon: Icons.pets,
  ),
  const LearningModel(
    name: "Everyday Objects",
    description: "Identify common objects around you.",
    icon: Icons.home,
  ),
  const LearningModel(
    name: "Numbers & Counting",
    description: "Learn numbers and basic counting skills.",
    icon: Icons.pin,
  ),
  const LearningModel(
    name: "Colors & Shapes",
    description: "Identify basic colors and geometric shapes.",
    icon: Icons.palette,
  ),
  const LearningModel(
    name: "Action Words",
    description: "Learn verbs and action words with animations.",
    icon: Icons.directions_run,
  ),
];
