import '../../helpers/cipher.dart';

String dgaAppsflyerKey() {
  const v = [184, 52, 228, 7, 148, 88, 61, 139, 200, 87, 97, 210, 31, 225, 139, 221, 26, 108, 222, 153, 202, 26];
  return unmask(v);
}

String dgaFirebaseNumber() {
  const v = [193, 77, 144, 77, 238, 83, 69, 246, 185, 24, 27, 165];
  return unmask(v);
}
