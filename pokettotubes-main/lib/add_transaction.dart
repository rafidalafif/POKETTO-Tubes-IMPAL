import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool isIncome = true;
  int? selectedCategoryId;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  // Data kategori dari database
  List<Map<String, dynamic>> incomeCategories = [];
  List<Map<String, dynamic>> expenseCategories = [];
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Load kategori dari database
  Future<void> _loadCategories() async {
    try {
      final db = DatabaseHelper.instance;
      
      final income = await db.getCategoriesByType('income');
      final expense = await db.getCategoriesByType('expense');
      
      setState(() {
        incomeCategories = income;
        expenseCategories = expense;
        
        // Set kategori default
        if (incomeCategories.isNotEmpty) {
          selectedCategoryId = incomeCategories.first['category_id'] as int;
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  // Simpan transaksi ke database
  Future<void> _saveTransaction() async {
    // Validasi input
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah tidak boleh kosong!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;

      if (userId == null) {
        throw Exception('User tidak ditemukan');
      }

      // Parse amount (hilangkan Rp dan titik)
      final amountStr = _amountController.text
          .replaceAll('Rp. ', '')
          .replaceAll('.', '')
          .trim();
      final amount = double.parse(amountStr);

      // Format tanggal ke YYYY-MM-DD
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

      final db = DatabaseHelper.instance;
      final result = await db.createTransaction(
        userId: userId,
        categoryId: selectedCategoryId!,
        amount: amount,
        description: _noteController.text.isEmpty 
            ? 'Transaksi ${isIncome ? "pemasukan" : "pengeluaran"}'
            : _noteController.text,
        date: dateStr,
      );

      if (!mounted) return;

      if (result > 0) {
        // Sukses
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke home
      } else {
        throw Exception('Gagal menyimpan transaksi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Format input dengan pemisah ribuan
  void _formatAmount(String value) {
    if (value.isEmpty) return;
    
    // Hapus semua karakter non-digit
    final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numericValue.isEmpty) {
      _amountController.text = '';
      return;
    }
    
    // Format dengan pemisah ribuan
    final formatter = NumberFormat('#,###', 'id_ID');
    final formatted = formatter.format(int.parse(numericValue));
    
    _amountController.value = TextEditingValue(
      text: 'Rp. ${formatted.replaceAll(',', '.')}',
      selection: TextSelection.collapsed(
        offset: 'Rp. ${formatted.replaceAll(',', '.')}'.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current categories based on isIncome
    final currentCategories = isIncome ? incomeCategories : expenseCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFED8A35),
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
              child: Row(
                children: [
                  // Tombol X
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Tambah Transaksi",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // ===== CONTENT CARD =====
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== TAB PEMASUKAN & PENGELUARAN =====
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isIncome = true;
                                // Reset kategori ke kategori income pertama
                                if (incomeCategories.isNotEmpty) {
                                  selectedCategoryId = incomeCategories.first['category_id'] as int;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isIncome
                                    ? const Color(0xFFED8A35)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Pemasukan",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isIncome
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isIncome = false;
                                // Reset kategori ke kategori expense pertama
                                if (expenseCategories.isNotEmpty) {
                                  selectedCategoryId = expenseCategories.first['category_id'] as int;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIncome
                                    ? const Color(0xFFED8A35)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Pengeluaran",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !isIncome
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // ===== LABEL JUMLAH =====
                      const Text(
                        "Jumlah",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ===== INPUT JUMLAH =====
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Rp. 0',
                            hintStyle: TextStyle(
                              color: Colors.black26,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: _formatAmount,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==== DROPDOWN KATEGORI ====
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: currentCategories.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(14.0),
                                child: Text('Loading kategori...'),
                              )
                            : DropdownButtonFormField<int>(
                                value: selectedCategoryId,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: currentCategories
                                    .map(
                                      (category) => DropdownMenuItem<int>(
                                        value: category['category_id'] as int,
                                        child: Text(category['name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => selectedCategoryId = value);
                                },
                              ),
                      ),

                      const SizedBox(height: 22),

                      // ===== INPUT TANGGAL =====
                      GestureDetector(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: selectedDate,
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('d MMMM yyyy')
                                        .format(selectedDate),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ===== INPUT CATATAN =====
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: "Catatan (Optional)",
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ===== SIMPAN BUTTON =====
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _saveTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED8A35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Simpan Transaksi",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}