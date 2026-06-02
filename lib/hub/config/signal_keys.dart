import '../../helpers/cipher.dart';

String dgaAppsflyerKey() => '';

String dgaFirebaseNumber() {
  const v = [76, 11, 119, 78, 103, 191, 201, 102, 224, 140, 39, 204];
  return unmask(v);
}
