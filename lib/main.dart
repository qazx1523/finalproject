import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'models/group.dart';
import 'models/transaction.dart';
import 'models/app_user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().userStream,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: '多人記帳分帳 APP',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AuthenticationWrapper(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    if (firebaseUser != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('多人分帳 APP', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 80),
              const Icon(Icons.account_balance_wallet, size: 100, color: Colors.teal),
              const SizedBox(height: 80),
              ElevatedButton.icon(
                onPressed: () => context.read<AuthService>().signInWithGoogle(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.grey),
                ),
                icon: Image.network(
                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                ),
                label: const Text('使用 Google 帳戶登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> pages = [
      const GroupListScreen(),
      const FriendListScreen(),
      const UserProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '群組'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '好友'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: '個人檔案'),
        ],
      ),
    );
  }
}

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<AppUser>(
      stream: firestore.getUserStream(user!.uid),
      builder: (context, userSnapshot) {
        final displayName = userSnapshot.data?.displayName ?? "...";
        return Scaffold(
          appBar: AppBar(
            title: Text('我的群組 ($displayName)'),
          ),
          body: StreamBuilder<List<Group>>(
            stream: firestore.getGroups(user.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final groups = snapshot.data!;
              return ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.group)),
                    title: Text(group.name),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id))),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateGroupDialog(context, user.uid),
            child: const Icon(Icons.add),
          ),
        );
      }
    );
  }

  void _showCreateGroupDialog(BuildContext context, String uid) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('建立新群組'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: '群組名稱')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              context.read<FirestoreService>().createGroup(controller.text, uid);
              Navigator.pop(context);
            },
            child: const Text('建立'),
          ),
        ],
      ),
    );
  }
}

class FriendListScreen extends StatelessWidget {
  const FriendListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<AppUser>(
      stream: firestore.getUserStream(user!.uid),
      builder: (context, userSnapshot) {
        final displayName = userSnapshot.data?.displayName ?? "...";
        return Scaffold(
          appBar: AppBar(
            title: Text('好友名單 ($displayName)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () => _showAddFriendDialog(context, user.uid),
              ),
            ],
          ),
          body: userSnapshot.hasData && userSnapshot.data!.friendIds.isNotEmpty
              ? FutureBuilder<List<AppUser>>(
                  future: firestore.getFriendsDetails(userSnapshot.data!.friendIds),
                  builder: (context, friendSnapshot) {
                    if (!friendSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final friends = friendSnapshot.data!;
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friend.displayName),
                          subtitle: Text(friend.email),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove, color: Colors.grey),
                            onPressed: () => _showDeleteFriendDialog(context, user.uid, friend.uid, friend.displayName),
                          ),
                        );
                      },
                    );
                  },
                )
              : const Center(child: Text('尚未加入好友')),
        );
      }
    );
  }

  void _showDeleteFriendDialog(BuildContext context, String uid, String friendUid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除好友'),
        content: Text('確定要將 $name 從好友名單移除嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await context.read<FirestoreService>().removeFriend(uid, friendUid);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, String uid) {
    final controller = TextEditingController();
    final firestore = context.read<FirestoreService>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增好友'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: '輸入好友 Email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final friend = await firestore.searchUserByEmail(controller.text);
              if (context.mounted) {
                if (friend != null) {
                  await firestore.addFriend(uid, friend.uid);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功加入好友')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到該用戶')));
                }
              }
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestore = context.read<FirestoreService>();
    final auth = context.read<AuthService>();

    return StreamBuilder<AppUser>(
      stream: firestore.getUserStream(user!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final appUser = snapshot.data!;
        if (_nameController.text.isEmpty) _nameController.text = appUser.displayName;

        return Scaffold(
          appBar: AppBar(
            title: Text('個人檔案 (${appUser.displayName})'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '顯示名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text('登入帳號: ${appUser.email}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    await firestore.updateUserName(appUser.uid, _nameController.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料已更新')));
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text('儲存修改'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => auth.signOut(),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('登出帳戶', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Map<String, String> _userNames = {};

  Future<void> _loadUserNames(List<String> memberIds) async {
    final firestore = context.read<FirestoreService>();
    final names = await firestore.getUserNames(memberIds);
    if (mounted) {
      setState(() {
        _userNames = names;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final user = context.watch<User?>();

    return StreamBuilder<Group>(
      stream: firestore.getGroupStream(widget.groupId),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = groupSnapshot.data!;
        
        if (!group.memberIds.contains(user!.uid)) {
          Future.microtask(() => Navigator.pop(context));
          return const SizedBox.shrink();
        }

        if (_userNames.length != group.memberIds.length || !group.memberIds.every((id) => _userNames.containsKey(id))) {
           _loadUserNames(group.memberIds);
        }

        bool isAdmin = group.adminId == user.uid;

        return StreamBuilder<AppUser>(
          stream: firestore.getUserStream(user.uid),
          builder: (context, userSnapshot) {
            final currentUserDisplayName = userSnapshot.data?.displayName ?? "...";
            return DefaultTabController(
              length: 3,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('${group.name} ($currentUserDisplayName)'),
                  actions: [
                    if (isAdmin)
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'delete') _showDeleteGroupConfirm(context, group);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'delete', child: Text('刪除群組', style: TextStyle(color: Colors.red))),
                        ],
                      )
                  ],
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: '支出'),
                      Tab(text: '統計'),
                      Tab(text: '成員'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    _buildTransactionTabs(firestore, group),
                    _buildStatisticsView(firestore, group, isAdmin),
                    _buildMemberListView(firestore, group, user.uid),
                  ],
                ),
                floatingActionButton: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tabController,
                      builder: (context, child) {
                        if (tabController.index == 0) {
                          return FloatingActionButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExpenseFormScreen(group: group, userNames: _userNames)),
                            ),
                            child: const Icon(Icons.add_shopping_cart),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  }
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showDeleteGroupConfirm(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除群組'),
        content: const Text('警告：刪除群組將會移除所有帳務資料，此操作無法復原。確定要刪除嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await context.read<FirestoreService>().deleteGroup(group.id);
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // exit group screen
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTabs(FirestoreService firestore, Group group) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: '當前'), Tab(text: '歷史')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTransactionList(firestore, group, false),
                _buildTransactionList(firestore, group, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(FirestoreService firestore, Group group, bool isSettled) {
    return StreamBuilder<List<TransactionModel>>(
      stream: firestore.getTransactions(group.id, isSettled: isSettled),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('查詢失敗，請檢查主控台是否需建立索引。\n錯誤：${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final txs = snapshot.data!;
        if (txs.isEmpty) return const Center(child: Text('目前沒有任何帳單'));
        return ListView.builder(
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            final payerName = _userNames[tx.payerId] ?? tx.payerId.substring(0, 5);
            return ListTile(
              title: Text(tx.title),
              subtitle: Text('$payerName 付款'),
              trailing: Text('\$${tx.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              onTap: isSettled ? null : () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => ExpenseFormScreen(group: group, userNames: _userNames, transaction: tx))
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsView(FirestoreService firestore, Group group, bool isAdmin) {
    return Column(
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showSettleConfirm(context, firestore, group),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('結算當前帳務'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
          ),
        Expanded(
          child: StreamBuilder<Map<String, double>>(
            stream: firestore.streamBalances(group.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final balances = snapshot.data!;
              if (balances.isEmpty) return const Center(child: Text('目前沒有未結算的帳務'));
              return ListView(
                padding: const EdgeInsets.all(16),
                children: balances.entries.map((e) {
                  final val = e.value;
                  final memberName = _userNames[e.key] ?? e.key.substring(0, 5);
                  return Card(
                    child: ListTile(
                      title: Text('成員: $memberName'),
                      trailing: Text(
                        val >= 0 ? '應收 \$${val.toStringAsFixed(1)}' : '應付 \$${val.abs().toStringAsFixed(1)}',
                        style: TextStyle(color: val >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSettleConfirm(BuildContext context, FirestoreService firestore, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認結算'),
        content: const Text('是否確認所有成員皆已完成還款？結算後當前帳務將移至歷史記錄且無法修改。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await firestore.settleAllTransactions(group.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('結算完成')));
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListView(FirestoreService firestore, Group group, String currentUid) {
    bool isAdmin = group.adminId == currentUid;
    return Column(
      children: [
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('邀請新成員'),
            onTap: () => _showInviteMemberDialog(context, group, currentUid),
          ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: group.memberIds.length,
            itemBuilder: (context, index) {
              final uid = group.memberIds[index];
              final name = _userNames[uid] ?? uid.substring(0, 5);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uid == group.adminId) const Chip(label: Text('管理員')),
                    if (isAdmin && uid != group.adminId)
                      IconButton(
                        tooltip: '賦予管理員身分',
                        icon: const Icon(Icons.shield, color: Colors.teal),
                        onPressed: () => _showPromoteAdminConfirm(context, group, uid, name),
                      ),
                    if ((isAdmin || uid == currentUid) && uid != group.adminId)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _showRemoveMemberConfirm(context, group, uid, name),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPromoteAdminConfirm(BuildContext context, Group group, String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更換管理員'),
        content: Text('確定要將管理員身分賦予 $name 嗎？您將失去管理權限。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await context.read<FirestoreService>().promoteToAdmin(group.id, uid);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('確定賦予'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberConfirm(BuildContext context, Group group, String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成員'),
        content: Text('確定要將 $name 移出群組嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              bool isInvolved = await context.read<FirestoreService>().isMemberInvolvedInTransactions(group.id, uid);
              if (context.mounted) {
                if (isInvolved) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('無法移除：$name 尚有相關的支出項目，請先刪除或修改相關帳單。'), backgroundColor: Colors.red),
                  );
                } else {
                  await context.read<FirestoreService>().removeMemberFromGroup(group.id, uid);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  void _showInviteMemberDialog(BuildContext context, Group group, String currentUid) {
    final firestore = context.read<FirestoreService>();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀請成員'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('從好友名單選擇或輸入 Email', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(controller: emailController, decoration: const InputDecoration(hintText: '輸入 Email')),
            const SizedBox(height: 20),
            const Text('好友名單：'),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: StreamBuilder<AppUser>(
                stream: firestore.getUserStream(currentUid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final friendIds = snapshot.data!.friendIds;
                  final availableFriends = friendIds.where((fid) => !group.memberIds.contains(fid)).toList();
                  
                  if (availableFriends.isEmpty) return const Center(child: Text('無可選好友'));
                  
                  return FutureBuilder<List<AppUser>>(
                    future: firestore.getFriendsDetails(availableFriends),
                    builder: (context, fSnapshot) {
                      if (!fSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final friends = fSnapshot.data!;
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, i) {
                          final f = friends[i];
                          return ListTile(
                            title: Text(f.displayName),
                            onTap: () async {
                              await firestore.addMemberToGroup(group.id, f.uid);
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final user = await firestore.searchUserByEmail(emailController.text);
              if (context.mounted) {
                if (user != null) {
                  if (group.memberIds.contains(user.uid)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('該用戶已在群組中')));
                  } else {
                    await firestore.addMemberToGroup(group.id, user.uid);
                    if (context.mounted) Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到該用戶')));
                }
              }
            },
            child: const Text('邀請'),
          ),
        ],
      ),
    );
  }
}

class ExpenseFormScreen extends StatefulWidget {
  final Group group;
  final Map<String, String> userNames;
  final TransactionModel? transaction; // If null, we are adding; else we are editing.

  const ExpenseFormScreen({super.key, required this.group, required this.userNames, this.transaction});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedPayerId = '';
  final Map<String, double> _splitAmounts = {};
  final Map<String, bool> _includedMembers = {};
  bool _isEqualSplit = true;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedPayerId = widget.transaction!.payerId;
      _splitAmounts.addAll(widget.transaction!.splitDetails);
      for (var id in widget.group.memberIds) {
        _includedMembers[id] = _splitAmounts[id] != null && _splitAmounts[id]! > 0;
      }
      _isEqualSplit = false; // Default to manual when editing to preserve details
    } else {
      _selectedPayerId = widget.group.memberIds.first;
      for (var id in widget.group.memberIds) {
        _splitAmounts[id] = 0.0;
        _includedMembers[id] = true;
      }
    }
  }

  void _updateSplits() {
    if (_isEqualSplit) {
      double total = double.tryParse(_amountController.text) ?? 0;
      int count = _includedMembers.values.where((v) => v).length;
      if (count > 0) {
        double share = total / count;
        setState(() {
          for (var id in widget.group.memberIds) {
            _splitAmounts[id] = _includedMembers[id]! ? share : 0.0;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.transaction != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '編輯支出' : '新增支出'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await context.read<FirestoreService>().deleteTransaction(widget.group.id, widget.transaction!.id);
                if (mounted) Navigator.pop(context);
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '支出項目 (如：午餐)')),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '總金額'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateSplits(),
            ),
            const SizedBox(height: 20),
            const Text('誰付的錢？', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedPayerId,
              isExpanded: true,
              items: widget.group.memberIds.map((id) {
                final name = widget.userNames[id] ?? id.substring(0, 5);
                return DropdownMenuItem(value: id, child: Text(name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedPayerId = val!),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('分攤給誰？', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('平均分攤'),
                    Switch(
                      value: _isEqualSplit,
                      onChanged: (val) {
                        setState(() => _isEqualSplit = val);
                        if (val) _updateSplits();
                      },
                    ),
                  ],
                )
              ],
            ),
            ...widget.group.memberIds.map((id) {
              final name = widget.userNames[id] ?? id.substring(0, 5);
              return CheckboxListTile(
                title: Text(name),
                value: _includedMembers[id],
                onChanged: (val) {
                  setState(() => _includedMembers[id] = val!);
                  _updateSplits();
                },
                secondary: _isEqualSplit
                    ? Text('\$${_splitAmounts[id]?.toStringAsFixed(1)}')
                    : SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(prefixText: '\$'),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: _splitAmounts[id]?.toStringAsFixed(1)),
                          onChanged: (val) {
                            _splitAmounts[id] = double.tryParse(val) ?? 0;
                          },
                        ),
                      ),
              );
            }),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                final total = double.tryParse(_amountController.text) ?? 0;
                
                // Validation: Check if split sum matches total amount
                double splitSum = _splitAmounts.values.fold(0, (sum, val) => sum + val);
                if ((splitSum - total).abs() > 0.1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('分配失敗：分配總額 (\$${splitSum.toStringAsFixed(1)}) 與總金額 (\$${total.toStringAsFixed(1)}) 不符'),
                      backgroundColor: Colors.red,
                    )
                  );
                  return;
                }

                final tx = TransactionModel(
                  id: isEditing ? widget.transaction!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                  groupId: widget.group.id,
                  title: _titleController.text,
                  amount: total,
                  payerId: _selectedPayerId,
                  splitDetails: _splitAmounts,
                  date: isEditing ? widget.transaction!.date : DateTime.now(),
                  category: 'General',
                  isSettled: false, // New transactions are always "Current"
                );

                if (isEditing) {
                  context.read<FirestoreService>().updateTransaction(tx);
                } else {
                  context.read<FirestoreService>().addTransaction(tx);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: Text(isEditing ? '儲存修改' : '儲存支出'),
            ),
          ],
        ),
      ),
    );
  }
}
