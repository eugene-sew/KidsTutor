class ArRuntimeCapabilities {
  final bool planeDetection;
  final bool imageTracking;
  final bool depth;
  final bool mesh;
  final bool geospatial;

  const ArRuntimeCapabilities({
    required this.planeDetection,
    required this.imageTracking,
    required this.depth,
    required this.mesh,
    required this.geospatial,
  });

  factory ArRuntimeCapabilities.fromMap(Map<String, dynamic> map) {
    bool b(String key) => (map[key] == true);
    return ArRuntimeCapabilities(
      planeDetection: b('planeDetection'),
      imageTracking: b('imageTracking'),
      depth: b('depth'),
      mesh: b('mesh'),
      geospatial: b('geospatial'),
    );
  }

  Map<String, dynamic> toMap() => {
        'planeDetection': planeDetection,
        'imageTracking': imageTracking,
        'depth': depth,
        'mesh': mesh,
        'geospatial': geospatial,
      };
}

