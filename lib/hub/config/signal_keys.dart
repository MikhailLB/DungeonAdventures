import '../../helpers/cipher.dart';

String dgaAppsflyerKey() {
  const v = [53, 114, 3, 4, 29, 180, 177, 27, 145, 195, 93, 187, 65, 129, 79, 81, 163, 246, 76, 98, 202, 246];
  return unmask(v);
}

String dgaFirebaseNumber() {
  const v = [76, 11, 119, 78, 103, 191, 201, 102, 224, 140, 39, 204];
  return unmask(v);
}
