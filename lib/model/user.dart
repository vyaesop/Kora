import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class UserModel {
  final String id;
  final String name;
  final String username;
  final String? profileImageUrl;
  final String? bio;
  final String? link;
  final List following;
  final List followers;

  // New fields for user categorization
  final String userType; // "Driver" or "Cargo"

  // Driver-specific fields
  final String? truckType; // "Big", "Medium", "Small"
  final String? licensePlate;
  final String? insurance;
  final String? licenseNumberPhoto;
  final String? driverTradeLicensePhoto;
  final String? licenseNumber;
  final String? libre;
  final String? tradeLicense; // Both user types can have trade licenses
  final String? tradeLicensePhoto; // Photo URL
  final String? tradeRegistrationCertificatePhoto;
  final String? tinNumber; // TIN number
  final String? idPhoto; // ID photo URL
  final bool? isRepresentative; // Is representative
  final String? representativePhoto; // Representative photo URL
  final List<String>? acceptedLoads; // Add this line
  final String? address; // Add this line
  final bool termsAccepted;
  final bool privacyAccepted;
  final String verificationStatus;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.followers = const [],
    this.following = const [],
    this.profileImageUrl,
    this.bio,
    this.link,
    required this.userType, // Ensure this is provided
    this.truckType,
    this.licensePlate,
    this.insurance,
    this.licenseNumberPhoto,
    this.driverTradeLicensePhoto,
    this.licenseNumber,
    this.libre,
    this.tradeLicense,
    this.tradeLicensePhoto,
    this.tradeRegistrationCertificatePhoto,
    this.tinNumber,
    this.idPhoto,
    this.isRepresentative,
    this.representativePhoto,
    this.acceptedLoads, // Add this line
    this.address, // Add this line
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.verificationStatus = 'not_submitted',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'link': link,
      'following': following,
      'followers': followers,
      'userType': userType,
      'truckType': truckType,
      'licensePlate': licensePlate,
      'insurance': insurance,
      'licenseNumberPhoto': licenseNumberPhoto,
      'driverTradeLicensePhoto': driverTradeLicensePhoto,
      'licenseNumber': licenseNumber,
      'libre': libre,
      'tradeLicense': tradeLicense,
      'tradeLicensePhoto': tradeLicensePhoto,
      'tradeRegistrationCertificatePhoto': tradeRegistrationCertificatePhoto,
      'tinNumber': tinNumber,
      'idPhoto': idPhoto,
      'isRepresentative': isRepresentative,
      'representativePhoto': representativePhoto,
      'acceptedLoads': acceptedLoads ?? [], // Add this line
      'address': address, // Add this line
      'termsAccepted': termsAccepted,
      'privacyAccepted': privacyAccepted,
      'verificationStatus': verificationStatus,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      profileImageUrl: map['profileImageUrl'] != null
          ? map['profileImageUrl'] as String
          : null,
      bio: map['bio'] != null ? map['bio'] as String : null,
      link: map['link'] != null ? map['link'] as String : null,
      followers: map['followers'] is List ? List.from(map['followers'] as List) : const [],
      following: map['following'] is List ? List.from(map['following'] as List) : const [],
      userType: map['userType'] as String, // Extract userType
      truckType: map['truckType'] != null ? map['truckType'] as String : null,
      licensePlate: map['licensePlate'] != null
          ? map['licensePlate'] as String
          : null,
      insurance: map['insurance'] != null ? map['insurance'] as String : null,
      licenseNumberPhoto: map['licenseNumberPhoto'] != null
          ? map['licenseNumberPhoto'] as String
          : null,
      driverTradeLicensePhoto: map['driverTradeLicensePhoto'] != null
          ? map['driverTradeLicensePhoto'] as String
          : null,
      licenseNumber: map['licenseNumber'] != null
          ? map['licenseNumber'] as String
          : null,
      libre: map['libre'] != null ? map['libre'] as String : null,
      tradeLicense: map['tradeLicense'] != null
          ? map['tradeLicense'] as String
          : null,
      tradeLicensePhoto: map['tradeLicensePhoto'] != null
          ? map['tradeLicensePhoto'] as String
          : null,
      tradeRegistrationCertificatePhoto:
          map['tradeRegistrationCertificatePhoto'] != null
          ? map['tradeRegistrationCertificatePhoto'] as String
          : null,
      tinNumber: map['tinNumber'] != null ? map['tinNumber'] as String : null,
      idPhoto: map['idPhoto'] != null ? map['idPhoto'] as String : null,
      isRepresentative: map['isRepresentative'] ?? false,
      representativePhoto: map['representativePhoto'] != null
          ? map['representativePhoto'] as String
          : null,
      acceptedLoads: map['acceptedLoads'] != null
          ? List<String>.from(map['acceptedLoads'])
          : [],
      address: map['address'] != null
          ? map['address'] as String
          : null, // Add this line
      termsAccepted: map['termsAccepted'] == true,
      privacyAccepted: map['privacyAccepted'] == true,
      verificationStatus: (map['verificationStatus'] ?? 'not_submitted')
          .toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
