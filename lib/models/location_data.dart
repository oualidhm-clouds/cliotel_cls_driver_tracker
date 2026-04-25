class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] is int 
              ? json['timestamp'] 
              : int.tryParse(json['timestamp'].toString()) ?? 0)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirebaseJson({
    required int driverId,
    required String driverName,
    required String tenantId,
    bool isOnline = true,
  }) {
    return {
      'driver_id': driverId,
      'driver_name': driverName,
      'tenant_id': tenantId,
      'lat': latitude,
      'lng': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'updated_at': DateTime.now().toIso8601String(),
      'is_online': isOnline,
    };
  }

  @override
  String toString() => 'LocationData(lat: $latitude, lng: $longitude)';
}
