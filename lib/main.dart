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
import 'package:intl/intl.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: '電子郵件')),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '密碼'), obscureText: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<AuthService>().signIn(_emailController.text, _passwordController.text),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('登入'),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('前往註冊'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '顯示名稱')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: '電子郵件')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '密碼'), obscureText: true),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await context.read<AuthService>().signUp(_emailController.text, _passwordController.text, _nameController.text);
                Navigator.pop(context);
              },
              child: const Text('註冊'),
            ),
          ],
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

    final List<Widget> _pages = [
      const GroupListScreen(),
      const FriendListScreen(),
    ];

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '群組'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '好友'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的群組'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
      body: StreamBuilder<List<Group>>(
        stream: firestore.getGroups(user!.uid),
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group))),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友名單'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddFriendDialog(context, user!.uid),
          ),
        ],
      ),
      body: StreamBuilder<AppUser>(
        stream: firestore.getUserStream(user!.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final appUser = snapshot.data!;
          if (appUser.friendIds.isEmpty) return const Center(child: Text('尚未加入好友'));
          
          return FutureBuilder<List<AppUser>>(
            future: firestore.getFriendsDetails(appUser.friendIds),
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
                  );
                },
              );
            },
          );
        },
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
              if (friend != null) {
                await firestore.addFriend(uid, friend.uid);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功加入好友')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到該用戶')));
              }
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final firestore = context.read<FirestoreService>();
    final names = await firestore.getUserNames(widget.group.memberIds);
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.group.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: '支出'),
              Tab(text: '結算'),
              Tab(text: '成員'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTransactionList(firestore),
            _buildSettlementView(firestore),
            _buildMemberListView(firestore, user!.uid),
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
                      MaterialPageRoute(builder: (_) => AddExpenseScreen(group: widget.group, userNames: _userNames)),
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

  Widget _buildTransactionList(FirestoreService firestore) {
    return StreamBuilder<List<TransactionModel>>(
      stream: firestore.getTransactions(widget.group.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final txs = snapshot.data!;
        return ListView.builder(
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            final payerName = _userNames[tx.payerId] ?? tx.payerId.substring(0, 5);
            return ListTile(
              title: Text(tx.title),
              subtitle: Text('$payerName 付款'),
              trailing: Text('\$${tx.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementView(FirestoreService firestore) {
    return FutureBuilder<Map<String, double>>(
      future: firestore.calculateBalances(widget.group.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final balances = snapshot.data!;
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
    );
  }

  Widget _buildMemberListView(FirestoreService firestore, String currentUid) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_add),
          title: const Text('邀請新成員'),
          onTap: () => _showInviteMemberDialog(context, currentUid),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: widget.group.memberIds.length,
            itemBuilder: (context, index) {
              final uid = widget.group.memberIds[index];
              final name = _userNames[uid] ?? uid.substring(0, 5);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                trailing: uid == widget.group.adminId ? const Chip(label: Text('管理員')) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showInviteMemberDialog(BuildContext context, String currentUid) {
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
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final friendIds = snapshot.data!.friendIds;
                  final availableFriends = friendIds.where((fid) => !widget.group.memberIds.contains(fid)).toList();
                  
                  if (availableFriends.isEmpty) return const Center(child: Text('無可選好友'));
                  
                  return FutureBuilder<List<AppUser>>(
                    future: firestore.getFriendsDetails(availableFriends),
                    builder: (context, fSnapshot) {
                      if (!fSnapshot.hasData) return const CircularProgressIndicator();
                      final friends = fSnapshot.data!;
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, i) {
                          final f = friends[i];
                          return ListTile(
                            title: Text(f.displayName),
                            onTap: () async {
                              await firestore.addMemberToGroup(widget.group.id, f.uid);
                              Navigator.pop(context);
                              _loadUserNames(); // Refresh names
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
              if (user != null) {
                if (widget.group.memberIds.contains(user.uid)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('該用戶已在群組中')));
                } else {
                  await firestore.addMemberToGroup(widget.group.id, user.uid);
                  Navigator.pop(context);
                  _loadUserNames();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到該用戶')));
              }
            },
            child: const Text('邀請'),
          ),
        ],
      ),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  final Group group;
  final Map<String, String> userNames;
  const AddExpenseScreen({super.key, required this.group, required this.userNames});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedPayerId = '';
  Map<String, double> _splitAmounts = {};
  Map<String, bool> _includedMembers = {};
  bool _isEqualSplit = true;

  @override
  void initState() {
    super.initState();
    _selectedPayerId = widget.group.memberIds.first;
    for (var id in widget.group.memberIds) {
      _splitAmounts[id] = 0.0;
      _includedMembers[id] = true;
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
    return Scaffold(
      appBar: AppBar(title: const Text('新增支出')),
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
                        width: 80,
                        child: TextField(
                          decoration: const InputDecoration(prefixText: '\$'),
                          keyboardType: TextInputType.number,
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
                final tx = TransactionModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  groupId: widget.group.id,
                  title: _titleController.text,
                  amount: total,
                  payerId: _selectedPayerId,
                  splitDetails: _splitAmounts,
                  date: DateTime.now(),
                  category: 'General',
                );
                context.read<FirestoreService>().addTransaction(tx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('儲存支出'),
            ),
          ],
        ),
      ),
    );
  }
}
