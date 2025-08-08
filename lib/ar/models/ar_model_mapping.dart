import 'package:vector_math/vector_math_64.dart';
import 'ar_model.dart';

/// A singleton class that maps detected letters/objects to their corresponding 3D models
class ARModelMapping {
  // Singleton instance
  static final ARModelMapping _instance = ARModelMapping._internal();

  // Factory constructor to return the singleton instance
  factory ARModelMapping() => _instance;

  // Private constructor
  ARModelMapping._internal();

  // Model mappings from letters to 3D models with enhanced rendering properties
  final Map<String, ARModel> _letterToModelMap = {
    'A': ARModel(
      id: 'apple',
      name: 'Apple',
      modelPath: 'assets/3d_models/apple.glb',
      scale: 0.2,
      pronunciation: 'A-pul',
      funFact: 'Apples float in water because they are 25% air!',
      shadowIntensity: 0.8,
      shadowSoftness: 0.6,
      exposure: 1.2,
      environmentLighting: 'neutral',
      autoRotate: true,
      autoRotateSpeed: 15.0,
      rotation: Vector3(0, 0.2, 0),
      levelOfDetail: 1,
      useCompressedTextures: true,
      maxTextureSize: 1024,
    ),
    'B': ARModel(
      id: 'ball',
      name: 'Ball',
      modelPath: 'assets/3d_models/ball.glb',
      scale: 0.15,
      pronunciation: 'Bawl',
      funFact:
          'The oldest known ball game was played by the Mayans over 3,000 years ago.',
      shadowIntensity: 0.7,
      shadowSoftness: 0.5,
      exposure: 1.0,
      environmentLighting: 'neutral',
      autoRotate: true,
      autoRotateSpeed: 25.0,
    ),
    'C': ARModel(
      id: 'cat',
      name: 'Cat',
      modelPath: 'assets/3d_models/cat.glb',
      scale: 0.18,
      pronunciation: 'Ka-t',
      funFact:
          'Cats can make over 100 different sounds while dogs can only make about 10!',
      shadowIntensity: 0.9,
      shadowSoftness: 0.7,
      exposure: 1.1,
      environmentLighting: 'neutral',
      autoRotate: false,
      rotation: Vector3(0, 0.3, 0),
    ),
    'D': ARModel(
      id: 'dog',
      name: 'Dog',
      modelPath: 'assets/3d_models/dog.glb',
      scale: 0.18,
      pronunciation: 'Daw-g',
      funFact:
          'A dog\'s nose print is unique, similar to a human\'s fingerprint.',
      shadowIntensity: 0.9,
      shadowSoftness: 0.7,
      exposure: 1.1,
      environmentLighting: 'neutral',
      autoRotate: false,
      rotation: Vector3(0, 0.3, 0),
    ),
    'E': ARModel(
      id: 'elephant',
      name: 'Elephant',
      modelPath: 'assets/3d_models/elephant.glb',
      scale: 0.15,
      pronunciation: 'E-luh-funt',
      funFact: 'Elephants are the only mammals that can\'t jump!',
      shadowIntensity: 1.0,
      shadowSoftness: 0.8,
      exposure: 1.0,
      environmentLighting: 'neutral',
      autoRotate: false,
      rotation: Vector3(0, 0.2, 0),
    ),
    'F': ARModel(
      id: 'fish',
      name: 'Fish',
      modelPath: 'assets/3d_models/fish.glb',
      scale: 0.2,
      pronunciation: 'Fi-sh',
      funFact: 'Some fish can fly above the water for short distances!',
      shadowIntensity: 0.6,
      shadowSoftness: 0.9,
      exposure: 1.2,
      environmentLighting: 'neutral',
      autoRotate: true,
      autoRotateSpeed: 20.0,
      rotation: Vector3(0, 0, 0.1),
    ),
    'G': ARModel(
      id: 'giraffe',
      name: 'Giraffe',
      modelPath: 'assets/3d_models/giraffe.glb',
      scale: 0.15,
      pronunciation: 'Juh-raf',
      funFact:
          'Giraffes have the same number of neck vertebrae as humans – seven!',
    ),
    'H': ARModel(
      id: 'horse',
      name: 'Horse',
      modelPath: 'assets/3d_models/horse.glb',
      scale: 0.18,
      pronunciation: 'Hor-s',
      funFact: 'Horses can sleep both standing up and lying down.',
    ),
    'I': ARModel(
      id: 'icecream',
      name: 'Ice Cream',
      modelPath: 'assets/3d_models/icecream.glb',
      scale: 0.2,
      pronunciation: 'Eye-s-kream',
      funFact:
          'The first ice cream cone was created during the 1904 World\'s Fair!',
    ),
    'J': ARModel(
      id: 'jug',
      name: 'Jug',
      modelPath: 'assets/3d_models/jug.glb',
      scale: 0.2,
      pronunciation: 'Juh-g',
      funFact: 'Ancient jugs were often made from animal skins or clay.',
    ),
    'K': ARModel(
      id: 'kite',
      name: 'Kite',
      modelPath: 'assets/3d_models/kite.glb',
      scale: 0.2,
      pronunciation: 'Ky-t',
      funFact: 'The longest kite ever flown was 3,394 feet (1,034 m) long!',
    ),
    'L': ARModel(
      id: 'lion',
      name: 'Lion',
      modelPath: 'assets/3d_models/lion.glb',
      scale: 0.18,
      pronunciation: 'Ly-un',
      funFact: 'A lion\'s roar can be heard from up to 5 miles away!',
    ),
    'M': ARModel(
      id: 'monkey',
      name: 'Monkey',
      modelPath: 'assets/3d_models/monkey.glb',
      scale: 0.18,
      pronunciation: 'Mun-kee',
      funFact: 'There are over 260 different species of monkeys in the world!',
    ),
    'N': ARModel(
      id: 'nest',
      name: 'Nest',
      modelPath: 'assets/3d_models/nest.glb',
      scale: 0.2,
      pronunciation: 'Ne-st',
      funFact:
          'The largest bird nest ever found was over 9 feet wide and 20 feet deep!',
    ),
    'O': ARModel(
      id: 'onion',
      name: 'Onion',
      modelPath: 'assets/3d_models/onion.glb',
      scale: 0.2,
      pronunciation: 'Un-yun',
      funFact:
          'Onions can make you cry because they release a gas that irritates your eyes.',
    ),
    'P': ARModel(
      id: 'parrot',
      name: 'Parrot',
      modelPath: 'assets/3d_models/parrot.glb',
      scale: 0.18,
      pronunciation: 'Pa-rut',
      funFact: 'Some parrots can live for over 100 years!',
    ),
    'Q': ARModel(
      id: 'queen',
      name: 'Queen',
      modelPath: 'assets/3d_models/queen.glb',
      scale: 0.18,
      pronunciation: 'Kw-een',
      funFact: 'Queen bees can lay up to 2,000 eggs in a single day!',
    ),
    'R': ARModel(
      id: 'rabbit',
      name: 'Rabbit',
      modelPath: 'assets/3d_models/rabbit.glb',
      scale: 0.18,
      pronunciation: 'Ra-bit',
      funFact: 'A rabbit\'s teeth never stop growing throughout its life!',
    ),
    'S': ARModel(
      id: 'sun',
      name: 'Sun',
      modelPath: 'assets/3d_models/sun.glb',
      scale: 0.2,
      pronunciation: 'Su-n',
      funFact: 'It takes light from the Sun about 8 minutes to reach Earth.',
    ),
    'T': ARModel(
      id: 'television',
      name: 'Television',
      modelPath: 'assets/3d_models/television.glb',
      scale: 0.2,
      pronunciation: 'Te-luh-vi-zhun',
      funFact:
          'The first TV remote control was called "Lazy Bones" and was connected by a wire!',
    ),
    'U': ARModel(
      id: 'umbrella',
      name: 'Umbrella',
      modelPath: 'assets/3d_models/umbrella.glb',
      scale: 0.2,
      pronunciation: 'Um-bre-luh',
      funFact:
          'Umbrellas were first used over 4,000 years ago in ancient Egypt!',
    ),
    'V': ARModel(
      id: 'van',
      name: 'Van',
      modelPath: 'assets/3d_models/van.glb',
      scale: 0.18,
      pronunciation: 'Va-n',
      funFact:
          'The word "van" comes from "caravan" which means a group of people traveling together.',
    ),
    'W': ARModel(
      id: 'watch',
      name: 'Watch',
      modelPath: 'assets/3d_models/watch.glb',
      scale: 0.2,
      pronunciation: 'Wah-ch',
      funFact: 'The first wristwatch was made for a woman in 1868!',
    ),
    'X': ARModel(
      id: 'xylophone',
      name: 'Xylophone',
      modelPath: 'assets/3d_models/xylophone.glb',
      scale: 0.2,
      pronunciation: 'Zy-luh-fone',
      funFact:
          'The xylophone is over 1,500 years old and originated in Africa!',
    ),
    'Y': ARModel(
      id: 'yam',
      name: 'Yam',
      modelPath: 'assets/3d_models/yam.glb',
      scale: 0.2,
      pronunciation: 'Ya-m',
      funFact: 'Some yams can grow to be over 5 feet long!',
    ),
    'Z': ARModel(
      id: 'zebra',
      name: 'Zebra',
      modelPath: 'assets/3d_models/zebra.glb',
      scale: 0.18,
      pronunciation: 'Zee-bruh',
      funFact:
          'Every zebra has a unique pattern of stripes, like human fingerprints!',
    ),
  };

  /// Get a model by letter
  ARModel? getModelForLetter(String letter) {
    return _letterToModelMap[letter.toUpperCase()];
  }

  /// Get a model by name
  ARModel? getModelByName(String name) {
    for (final model in _letterToModelMap.values) {
      if (model.name.toLowerCase() == name.toLowerCase()) {
        return model;
      }
    }
    return null;
  }

  /// Get all available models
  List<ARModel> getAllModels() {
    return _letterToModelMap.values.toList();
  }

  /// Get all available letters
  List<String> getAllLetters() {
    return _letterToModelMap.keys.toList();
  }

  /// Get a model with adjusted level of detail based on performance requirements
  ARModel? getModelWithOptimizedLOD(String letter, bool isPerformanceDegraded) {
    final model = getModelForLetter(letter);
    if (model == null) return null;

    if (isPerformanceDegraded) {
      // Return a lower detail version for better performance
      return model.getLowerDetailVersion();
    } else {
      // Return the standard model
      return model;
    }
  }
}
