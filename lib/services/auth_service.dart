import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;


  Stream<User?> get authStateChanges => _auth.authStateChanges();


  User? get currentUser => _auth.currentUser;


  Future<String> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {

      final usernameCheck = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        return 'Username đã được sử dụng';
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );


      final newUser = UserModel(
        uid: credential.user!.uid,
        username: username,
        email: email,
        photoUrl: '',
        bio: '',
        followers: [],
        following: [],
      );

      await _db
          .collection('users')
          .doc(credential.user!.uid)
          .set(newUser.toMap());

      return 'success';
    } on FirebaseAuthException catch (e) {

      if (e.code == 'weak-password') return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
      if (e.code == 'email-already-in-use') return 'Email đã được sử dụng';
      if (e.code == 'invalid-email') return 'Email không hợp lệ';
      return e.message ?? 'Đăng ký thất bại';
    } catch (e) {
      return e.toString();
    }
  }


  Future<String> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return 'success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'Không tìm thấy tài khoản';
      if (e.code == 'wrong-password') return 'Sai mật khẩu';
      if (e.code == 'invalid-credential') return 'Email hoặc mật khẩu không đúng';
      return e.message ?? 'Đăng nhập thất bại';
    } catch (e) {
      return e.toString();
    }
  }


  Future<void> logout() async {
    await _auth.signOut();
  }


  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return UserModel.fromDoc(doc);
      return null;
    } catch (e) {
      return null;
    }
  }
}