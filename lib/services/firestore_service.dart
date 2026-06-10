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

  Stream<Group> getGroupStream(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) => Group.fromMap(doc.data() as Map<String, dynamic>));
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _db.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _db.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId])
    });
  }

  Future<void> promoteToAdmin(String groupId, String newAdminId) async {
    await _db.collection('groups').doc(groupId).update({
      'adminId': newAdminId
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final txs = await _db.collection('groups').doc(groupId).collection('transactions').get();
    for (var doc in txs.docs) {
      await doc.reference.delete();
    }
    await _db.collection('groups').doc(groupId).delete();
  }

  Future<bool> isMemberInvolvedInTransactions(String groupId, String userId) async {
    // A member can be removed if they are not part of any "Current" (unsettled) transaction.
    // Settlement effectively archives their involvement, allowing them to leave the group
    // without affecting the active balance of others.
    
    // We query for any transaction in the group where isSettled is NOT true
    // (handles false and legacy null values)
    final snapshot = await _db.collection('groups').doc(groupId).collection('transactions').get();
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Only care about UNSETTLED transactions
      if (data['isSettled'] == true) continue;

      // Check if user is the payer
      if (data['payerId'] == userId) return true;
      
      // Check if user is in splitDetails
      final splitDetails = data['splitDetails'] as Map?;
      if (splitDetails != null && splitDetails.containsKey(userId)) {
        return true;
      }
    }
    return false;
  }

  // User Operations
  Future<void> updateUserName(String uid, String newName) async {
    await _db.collection('users').doc(uid).update({
      'displayName': newName,
    });
  }

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

  Future<void> removeFriend(String currentUserId, String friendUserId) async {
    await _db.collection('users').doc(currentUserId).update({
      'friendIds': FieldValue.arrayRemove([friendUserId])
    });
  }

  Stream<AppUser> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>));
  }

  Future<List<AppUser>> getFriendsDetails(List<String> friendIds) async {
    if (friendIds.isEmpty) return [];
    
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

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _db
        .collection('groups')
        .doc(transaction.groupId)
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTransaction(String groupId, String transactionId) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  Future<void> settleAllTransactions(String groupId) async {
    // Settle all transactions that are not already settled.
    final snapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .get();
    
    WriteBatch batch = _db.batch();
    bool hasUpdates = false;
    for (var doc in snapshot.docs) {
      if (doc.data()['isSettled'] != true) {
        batch.update(doc.reference, {'isSettled': true});
        hasUpdates = true;
      }
    }
    if (hasUpdates) await batch.commit();
  }

  Stream<List<TransactionModel>> getTransactions(String groupId, {bool? isSettled}) {
    // Query optimization: filter then order. 
    // Note: Requires a composite index in Firestore for (isSettled, date).
    Query query = _db.collection('groups').doc(groupId).collection('transactions');
    
    if (isSettled != null) {
      query = query.where('isSettled', isEqualTo: isSettled);
    }
    
    query = query.orderBy('date', descending: true);

    return query.snapshots().map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Real-time Debt Analysis
  Stream<Map<String, double>> streamBalances(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .snapshots()
        .map((snapshot) {
      Map<String, double> balances = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['isSettled'] == true) continue;
        
        TransactionModel tx = TransactionModel.fromMap(data);
        balances[tx.payerId] = (balances[tx.payerId] ?? 0.0) + tx.amount;
        tx.splitDetails.forEach((userId, share) {
          balances[userId] = (balances[userId] ?? 0.0) - share;
        });
      }
      return balances;
    });
  }

  Future<Map<String, double>> calculateBalances(String groupId) async {
    final snapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('transactions')
        .get();

    Map<String, double> balances = {}; 

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['isSettled'] == true) continue;
      
      TransactionModel tx = TransactionModel.fromMap(data);
      balances[tx.payerId] = (balances[tx.payerId] ?? 0.0) + tx.amount;

      tx.splitDetails.forEach((userId, share) {
        balances[userId] = (balances[userId] ?? 0.0) - share;
      });
    }
    return balances;
  }
}
