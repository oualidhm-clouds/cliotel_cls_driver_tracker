class Driver {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? vehicleNumber;
  final String? vehicleType;
  final String status;
  final String? profilePhoto;
  final DateTime? createdAt;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.vehicleNumber,
    this.vehicleType,
    this.status = 'active',
    this.profilePhoto,
    this.createdAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      vehicleNumber: json['vehicle_number'],
      vehicleType: json['vehicle_type'],
      status: json['status'] ?? 'active',
      profilePhoto: json['profile_photo'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'status': status,
      'profile_photo': profilePhoto,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Driver copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? vehicleNumber,
    String? vehicleType,
    String? status,
    String? profilePhoto,
    DateTime? createdAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Driver(id: $id, name: $name, phone: $phone)';
}
