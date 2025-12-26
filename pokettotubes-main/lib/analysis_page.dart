import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';

// INSTRUKSI INTEGRASI:
// 1. Simpan file ini sebagai: lib/analysis_page.dart
// 2. Buka file home.dart
// 3. Tambahkan import di bagian atas:
//    import 'package:poketto/analysis_page.dart';
// 4. Cari bagian "Stats Icon" di bottom navigation (sekitar baris 496)
// 5. Ganti kode ini:
/*
                        // Stats Icon
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fitur Statistik belum tersedia'),
                              ),
                            );
                          },
*/
// 6. Dengan kode ini:
/*
                        // Stats Icon
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AnalysisPage(),
                              ),
                            );
                          },
*/

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  DateTime selectedMonth = DateTime.now();
  bool isLoading = true;
  double balance = 0.0;
  List<Map<String, dynamic>> weeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final monthStr = DateFormat('yyyy-MM').format(selectedMonth);

      // Get monthly stats
      final stats = await db.getMonthlyStats(userId, monthStr);
      
      // Get transactions untuk chart
      final transactions = await db.getTransactionsByMonth(userId, monthStr);
      
      // Process data untuk chart (per minggu)
      final weekly = _processWeeklyData(transactions);

      setState(() {
        balance = stats['balance'] ?? 0.0;
        weeklyData = weekly;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading financial data: $e');
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _processWeeklyData(List<Map<String, dynamic>> transactions) {
    // Group transactions by week
    Map<int, double> weeklyBalance = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    for (var tx in transactions) {
      try {
        final date = DateTime.parse(tx['date']);
        final day = date.day;
        final week = ((day - 1) ~/ 7) + 1;
        final amount = (tx['amount'] as num).toDouble();
        final isIncome = tx['category_type'] == 'income';
        
        if (week <= 5) {
          weeklyBalance[week] = (weeklyBalance[week] ?? 0) + (isIncome ? amount : -amount);
        }
      } catch (e) {
        print('Error processing transaction: $e');
      }
    }

    // Convert to list with cumulative balance
    double cumulative = 0;
    List<Map<String, dynamic>> result = [];
    
    for (int i = 1; i <= 5; i++) {
      cumulative += weeklyBalance[i] ?? 0;
      result.add({
        'week': i,
        'balance': cumulative,
        'label': '${(i - 1) * 7 + 1}-${i * 7}',
      });
    }
    
    return result;
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String getMonthName(DateTime date) {
    // Gunakan nama bulan manual untuk menghindari locale issue
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[date.month - 1];
  }

  void _changeMonth(int direction) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + direction,
        1,
      );
    });
    _loadFinancialData();
  }

  @override
  Widget build(BuildContext context) {
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Target Keuangan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // ===== CONTENT =====
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ===== MONTH SELECTOR =====
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    getMonthName(selectedMonth),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _changeMonth(-1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFED8A35),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.chevron_left,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _changeMonth(1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFED8A35),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 25),

                              // ===== FINANCIAL ANALYSIS CARD =====
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Financial Analysis",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "${balance >= 0 ? '+' : ''}${formatCurrency(balance)}",
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: balance >= 0 
                                            ? const Color(0xFFED8A35)
                                            : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 25),

                                    // ===== CHART =====
                                    SizedBox(
                                      height: 160,
                                      child: weeklyData.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Tidak ada data',
                                                style: TextStyle(
                                                  color: Colors.black38,
                                                ),
                                              ),
                                            )
                                          : CustomPaint(
                                              painter: BarChartPainter(
                                                data: weeklyData,
                                                maxValue: _getMaxValue(),
                                              ),
                                              size: const Size(double.infinity, 160),
                                            ),
                                    ),

                                    const SizedBox(height: 15),

                                    // ===== CHART LABELS =====
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: weeklyData.map((data) {
                                        return Text(
                                          data['label'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

                              // ===== LAPORAN KEUANGAN CARD =====
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Laporan Keuangan",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Unduh laporan keuangan bulan ini dalam format PDF",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          // TODO: Implement PDF generation
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Fitur unduh laporan belum tersedia',
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFED8A35),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          "Unduh Laporan Bulan Ini",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxValue() {
    if (weeklyData.isEmpty) return 1000000;
    
    double max = weeklyData
        .map((e) => (e['balance'] as double).abs())
        .reduce((a, b) => a > b ? a : b);
    
    return max * 1.2; // Add 20% padding
  }
}

// ===== CUSTOM BAR CHART PAINTER =====
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;

  BarChartPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFED8A35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (data.isEmpty) return;

    final barWidth = size.width / data.length;
    final chartHeight = size.height - 10;

    // Draw line chart
    final path = Path();
    bool firstPoint = true;

    for (int i = 0; i < data.length; i++) {
      final balance = data[i]['balance'] as double;
      final x = (i * barWidth) + (barWidth / 2);
      final normalizedHeight = (balance.abs() / maxValue) * chartHeight;
      final y = chartHeight - normalizedHeight;

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = const Color(0xFFED8A35)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}