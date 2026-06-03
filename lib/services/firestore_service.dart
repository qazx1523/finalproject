import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Group Operations
  Future<void> createGroup(String name, String adminId) async {
    String groupId = _db.collection('groups').doc().id;
    Group group = Group(
      id: groupId,
      name: name,
      adminId: adminId,
      memberIds: [adminId],
      createdAt: DateTime.now(),
    );
    await _db.collection('groups').doc(groupId).set(group.toMap());
  }

  Stream<List<Group>> getGroups(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _db.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId])
    });
  }

  // User Operations
  Future<AppUser?> searchUserByEmail(String email) async {
    QuerySnapshot snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return AppUser.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> addFriend(String currentUserId, String friendUserId) async {
    await _db.collection('users').doc(currentUserId).update({
      'friendIds': FieldValue.arrayUnion([friendUserId])
    });
  }

  Stream<AppUser> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>));
  }

  Future<List<AppUser>> getFriendsDetails(List<String> friendIds) async {
    if (friendIds.isEmpty) return [];
    
    // Firestore 'in' query supports up to 30 values
    QuerySnapshot snapshot = await _db
        .collection('users')
        .where('uid', whereIn: friendIds)
        .get();
    
    return snapshot.docs.map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  Future<Map<String, String>> getUserNames(List<String> uids) async {
    if (uids.isEmpty) return {};
    
    QuerySnapshot snapshot = await _db
        .collection('users')
        .where('uid', whereIn: uids)
        .get();
    
    return {
      for (var doc in snapshot.docs)
        (doc.data() as Map<String, dynamic>)['uid'] as String: 
        (doc.data() as Map<String, dynamic>)['displayName'] as String
    };
  }

  // Transaction Operations
  Future<void> addTransaction(TransactionModel transaction) async {
    await _db
        .collection('groups')
        .doc(transaction.groupId)
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
  }

  Stream<List<TransactionModel>> getTransactions(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Debt Analysis
  Future<Map<String, double>> calculateBalances(String groupId) async {
    QuerySnapshot snapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .get();

    Map<String, double> balances = {}; 

    for (var doc in snapshot.docs) {
      TransactionModel tx = TransactionModel.fromMap(doc.data() as Map<String, dynamic>);
      
      balances[tx.payerId] = (balances[tx.payerId] ?? 0.0) + tx.amount;

      tx.splitDetails.forEach((userId, share) {
        balances[userId] = (balances[userId] ?? 0.0) - share;
      });
    }
    return balances;
  }
}
