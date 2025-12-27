import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poketto/add_transaction.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/analysis_page.dart';
import 'package:poketto/folder_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poketto/all_categories_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OverlayEntry? _overlayEntry;

  String userName = 'User';
  double saldo = 0.0;
  double pengeluaran = 0.0;
  int rewardPoints = 0;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  List<Map<String, dynamic>> _folders = [];

  bool _isSelectionMode = false;
  final Set<int> _selectedTransactions = <int>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Memulai mode seleksi untuk mengelompokkan transaksi.
  void _enterSelectionMode() {
    hidePopupMenu();
    setState(() {
      _isSelectionMode = true;
      _selectedTransactions.clear();
    });
  }

  /// Keluar dari mode seleksi dan membersihkan item yang dipilih.
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTransactions.clear();
    });
  }

  /// Menampilkan dialog untuk membuat kategori baru.
  Future<void> _showCreateFolderDialog() async {
    final folderNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Buat Kategori Baru'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: folderNameController,
              decoration: const InputDecoration(hintText: "Contoh: Liburan Bali"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kategori tidak boleh kosong';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Buat'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final db = DatabaseHelper.instance;
                  final folderName = folderNameController.text.trim();
                  final transactionIds = _selectedTransactions.toList();

                  await db.createFolder(userProvider.userId!, folderName, transactionIds);

                  if (!mounted) return;

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kategori "$folderName" berhasil dibuat')),
                  );

                  _exitSelectionMode();
                  _loadData();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Menampilkan bottom sheet untuk menambahkan transaksi ke kategori yang sudah ada.
  Future<void> _showAddToFolderDialog() async {
    if (_folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada kategori. Buat kategori baru terlebih dahulu.')),
      );
      return;
    }

    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Tambahkan ke Kategori',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _folders.length,
                itemBuilder: (context, index) {
                  final folder = _folders[index];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined, color: Color(0xFFED8A35)),
                    title: Text(folder['name']),
                    subtitle: Text('${folder['transaction_count']} items'),
                    onTap: () async {
                      final db = DatabaseHelper.instance;
                      final folderId = folder['folder_id'] as int;
                      final transactionIds = _selectedTransactions.toList();

                      await db.addTransactionsToFolder(folderId, transactionIds);

                      if (!mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Berhasil menambahkan ke kategori "${folder['name']}"')),
                      );

                      _exitSelectionMode();
                      _loadData();
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mengambil semua data yang diperlukan untuk halaman utama dari database.
  Future<void> _loadData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final user = await db.getUserById(userId);
      if (user != null) {
        userName = user['name'] as String;
      }
      final now = DateTime.now();
      final currentMonth = DateFormat('yyyy-MM').format(now);
      final stats = await db.getMonthlyStats(userId, currentMonth);
      final txList = await db.getTransactionsByMonth(userId, currentMonth);
      final points = await db.getRewardPoints(userId);
      final folderList = await db.getFoldersByUser(userId);

      setState(() {
        saldo = stats['balance'] ?? 0.0;
        pengeluaran = stats['expense'] ?? 0.0;
        rewardPoints = points ?? 0;
        transactions = txList;
        _folders = folderList;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  /// Memformat angka menjadi format mata uang Rupiah.
  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Mendapatkan ikon yang sesuai berdasarkan nama kategori.
  IconData getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.help_outline;
    switch (categoryName.toLowerCase()) {
      case 'gaji':
      case 'bonus':
        return Icons.attach_money_rounded;
      case 'makanan':
        return Icons.restaurant_outlined;
      case 'transport':
      case 'bensin':
        return Icons.directions_car_outlined;
      case 'hiburan':
        return Icons.movie_outlined;
      case 'belanja':
        return Icons.shopping_bag_outlined;
      case 'tagihan':
        return Icons.receipt_long_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  /// Menampilkan menu pop-up untuk "Tambah Transaksi" dan "Tambah Kategori".
  void showPopupMenu() {
    hidePopupMenu();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 110,
        left: MediaQuery.of(context).size.width / 2 - 100,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    hidePopupMenu();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
                    );
                    _loadData();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.black),
                        SizedBox(width: 10),
                        Text("Tambah Transaksi", style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                Container(height: 1, color: Colors.black12),
                InkWell(
                  onTap: _enterSelectionMode,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder_outlined, color: Colors.black),
                        SizedBox(width: 10),
                        Text("Tambah Kategori", style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hidePopupMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  /// Metode utama yang membangun seluruh UI halaman utama.
  Widget build(BuildContext context) {
    final currentMonth = DateFormat('MMMM').format(DateTime.now());

    return Scaffold(
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isSelectionMode) _buildOrangeHeader(currentMonth),
                Expanded(
                  child: _isSelectionMode
                      ? _buildSelectionList()
                      : _buildNormalContent(),
                ),
                if (!_isSelectionMode) _buildMainBottomNav(),
              ],
            ),
    );
  }

  /// Membangun bottom bar yang muncul saat dalam mode seleksi.
  Widget _buildSelectionBottomBar() {
    return BottomAppBar(
      elevation: 8,
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _exitSelectionMode,
              child: const Text('Batal', style: TextStyle(fontSize: 16)),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _selectedTransactions.isEmpty
                      ? null
                      : _showAddToFolderDialog,
                  child: const Text('Add'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _selectedTransactions.isEmpty
                      ? null
                      : _showCreateFolderDialog,
                  child: const Text('New'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun daftar transaksi yang bisa dipilih saat dalam mode seleksi.
  Widget _buildSelectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Pilih Transaksi (${_selectedTransactions.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('Tidak ada transaksi untuk dipilih.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isSelected = _selectedTransactions.contains(tx['transaction_id']);
                    return Card(
                      elevation: isSelected ? 3 : 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isSelected
                            ? const BorderSide(color: Color(0xFFED8A35), width: 1.5)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTransactions.remove(tx['transaction_id']);
                            } else {
                              _selectedTransactions.add(tx['transaction_id'] as int);
                            }
                          });
                        },
                        child: _transaksiItem(
                          icon: getCategoryIcon(tx['category_name']),
                          title: tx['category_name'] ?? 'Unknown',
                          tanggal: _formatDate(tx['date']),
                          nominal: (tx['category_type'] == 'income')
                              ? formatCurrency((tx['amount'] as num).toDouble())
                              : "-${formatCurrency((tx['amount'] as num).toDouble())}",
                          isPositive: tx['category_type'] == 'income',
                          description: tx['description'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Membangun seluruh area konten utama yang bisa di-scroll.
  Widget _buildNormalContent() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F2),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Column(
                  children: [
                    // REWARD POINTS CARD
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED8A35),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black.withOpacity(0.15), width: 3),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.stars_rounded, color: Color(0xFFED8A35), size: 24),
                                  const SizedBox(height: 2),
                                  Text("$rewardPoints", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4A4A4A))),
                                ],
                              ),
                            ),
                          ),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Reward", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                              SizedBox(height: 2),
                              Text("Points", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // BAGIAN KATEGORI
                    _buildFolderList(),

                    // PEMBATAS "BULAN INI"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Bulan Ini", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fitur See All belum tersedia')),
                              );
                            },
                            child: const Text("See all", style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // DAFTAR TRANSAKSI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: transactions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
                              SizedBox(height: 16),
                              Text('Belum ada transaksi', style: TextStyle(fontSize: 16, color: Colors.black45)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return _transaksiItem(
                              icon: getCategoryIcon(tx['category_name']),
                              title: tx['category_name'] ?? 'Unknown',
                              tanggal: _formatDate(tx['date']),
                              nominal: (tx['category_type'] == 'income')
                                  ? formatCurrency((tx['amount'] as num).toDouble())
                                  : "-${formatCurrency((tx['amount'] as num).toDouble())}",
                              isPositive: tx['category_type'] == 'income',
                              description: tx['description'] ?? '',
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Membangun bagian daftar kategori di halaman utama.
  Widget _buildFolderList() {
    final int itemCount = _folders.length > 3 ? 3 : _folders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Kategori Saya",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              if (_folders.length > 3)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AllCategoriesPage()),
                    );
                  },
                  child: const Text(
                    "Lihat Semua",
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _folders.isEmpty
            ? _buildEmptyCategoryPlaceholder()
            : Column(
                children: List.generate(itemCount, (index) {
                  final folder = _folders[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _kategoriItem(
                      name: folder['name'],
                      itemCount: folder['transaction_count'] as int,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FolderDetailPage(
                              folderId: folder['folder_id'] as int,
                              folderName: folder['name'] as String,
                            ),
                          ),
                        ).then((_) {
                          _loadData();
                        });
                      },
                    ),
                  );
                }),
              ),
      ],
    );
  }

  /// Membangun placeholder yang tampil jika belum ada kategori yang dibuat.
  Widget _buildEmptyCategoryPlaceholder() {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.create_new_folder_outlined, color: Colors.grey, size: 28),
            SizedBox(width: 12),
            Text(
              'Belum ada kategori',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun header oranye di bagian atas halaman.
  Widget _buildOrangeHeader(String currentMonth) {
    return Container(
      color: const Color(0xFFED8A35),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back, $userName",
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentMonth,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.black87, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.black.withOpacity(0.7)),
                              const SizedBox(width: 5),
                              Text("Saldo", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.7))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(saldo),
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 2, height: 45, color: Colors.white),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_circle_up_outlined, size: 14, color: Colors.black.withOpacity(0.7)),
                              const SizedBox(width: 5),
                              Text("Pengeluaran", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.7))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "-${formatCurrency(pengeluaran)}",
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun bar navigasi utama di bagian bawah halaman.
  Widget _buildMainBottomNav() {
    return Container(
      color: const Color(0xFFF4F4F2),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 65,
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEED9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_outlined, size: 26, color: Color(0xFFED8A35)),
            ),
            GestureDetector(
              onTap: () {
                if (_overlayEntry == null) {
                  showPopupMenu();
                } else {
                  hidePopupMenu();
                }
              },
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalysisPage()),
                );
              },
              child: SizedBox(
                width: 45,
                height: 45,
                child: Icon(Icons.insert_chart_outlined_rounded, size: 28, color: Colors.black.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Memformat tanggal dari string menjadi format yang mudah dibaca (contoh: 17 Agustus).
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// Menampilkan bottom sheet menu profil pengguna.
  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(userProvider.userName ?? 'User'),
                subtitle: Text(userProvider.userEmail ?? ''),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Meng-handle proses logout pengguna.
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin mau logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Provider.of<UserProvider>(context, listen: false).logout();

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userId');

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan satu item transaksi.
  Widget _transaksiItem({
    required IconData icon,
    required String title,
    required String tanggal,
    required String nominal,
    required bool isPositive,
    String description = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFDEED9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFED8A35), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(
                  tanggal,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFED8A35)),
                ),
              ],
            ),
          ),
          Text(
            nominal,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPositive ? Colors.black87 : const Color(0xFFED8A35),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan satu item kategori (yang dibuat pengguna).
  Widget _kategoriItem({
    required String name,
    required int itemCount,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFDEED9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.folder_open_rounded, color: Color(0xFFED8A35), size: 26),
        ),
        title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text('$itemCount items', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
