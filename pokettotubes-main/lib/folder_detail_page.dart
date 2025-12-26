import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';

class FolderDetailPage extends StatefulWidget {
  final int folderId;
  final String folderName;

  const FolderDetailPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedTransactions = <int>{};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = DatabaseHelper.instance;
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await db.getTransactionsInFolder(widget.folderId);
    if (mounted) {
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    }
  }

  void _enterSelectionMode(int transactionId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTransactions.add(transactionId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTransactions.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedTransactions.length == _transactions.length) {
        _selectedTransactions.clear();
      } else {
        _selectedTransactions.clear();
        for (var tx in _transactions) {
          _selectedTransactions.add(tx['transaction_id'] as int);
        }
      }
    });
  }

  Future<void> _removeSelectedTransactions() async {
    final db = DatabaseHelper.instance;
    final transactionIds = _selectedTransactions.toList();

    await db.removeTransactionsFromFolder(widget.folderId, transactionIds);
    await db.deleteEmptyFolders();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${transactionIds.length} transaksi dikeluarkan')),
    );

    _exitSelectionMode();
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTransactionList(),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.folderName),
      backgroundColor: const Color(0xFFED8A35),
      foregroundColor: Colors.black,
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final isAllSelected = _selectedTransactions.length == _transactions.length;
    return AppBar(
      backgroundColor: Colors.grey.shade200,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedTransactions.length} dipilih'),
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: Text(isAllSelected ? 'Deselect All' : 'Select All'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Keluarkan dari kategori',
          onPressed: _selectedTransactions.isEmpty ? null : _removeSelectedTransactions,
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_zip_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 16),
            Text('Kategori ini kosong', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final isSelected = _selectedTransactions.contains(tx['transaction_id']);

          return Card(
            elevation: isSelected ? 4 : 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected ? const BorderSide(color: Color(0xFFED8A35), width: 1.5) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedTransactions.remove(tx['transaction_id']);
                    } else {
                      _selectedTransactions.add(tx['transaction_id'] as int);
                    }
                  });
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(tx['transaction_id'] as int);
                }
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
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0);
    return formatter.format(amount);
  }

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

  Widget _transaksiItem({
    required IconData icon,
    required String title,
    required String tanggal,
    required String nominal,
    required bool isPositive,
    String description = '',
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                  description.isNotEmpty ? description : title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
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
}
