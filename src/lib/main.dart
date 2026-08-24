import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DolarVE',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.emerald,
      ),
      home: const CalculatorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RateItem {
  final String id;
  final String name;
  final double rate;
  final Color color1;
  final Color color2;
  final String subtitle;

  RateItem(this.id, this.name, this.rate, this.color1, this.color2, this.subtitle);
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  List<RateItem> rates = [];
  double currentRate = 36.45;
  String currentName = 'BCV';
  double avgRate = 38.70;
  bool isOnline = true;
  bool isLoading = true;

  final TextEditingController vesController = TextEditingController();
  final TextEditingController usdController = TextEditingController();
  final TextEditingController usdAvgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Default fallback rates
    List<RateItem> fetchedRates = [
      RateItem('bcv', 'BCV', 36.45, const Color(0xFF00247D), const Color(0xFFCF142B), 'Banco Central de Venezuela'),
      RateItem('paralelo', 'Paralelo', 38.60, const Color(0xFF0f5132), const Color(0xFF198754), 'Monitor Dólar'),
      RateItem('binance', 'Binance', 38.25, const Color(0xFFF3BA2F), const Color(0xFFF0B90B), 'Mercado P2P'),
      RateItem('paypal', 'PayPal', 41.50, const Color(0xFF003087), const Color(0xFF0079C1), 'Comisiones estimadas'),
    ];

    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        fetchedRates = [];
        double sum = 0;
        int count = 0;
        
        for (var item in data) {
          String id = item['casa'] ?? '';
          String name = item['nombre'] ?? '';
          double rate = (item['promedio'] ?? item['venta'] ?? 0.0).toDouble();
          
          if (rate <= 0) continue;
          
          sum += rate;
          count++;

          Color c1 = Colors.grey[800]!;
          Color c2 = Colors.grey[700]!;
          String sub = 'Tasa actualizada';

          if (id == 'bcv') { c1 = const Color(0xFF00247D); c2 = const Color(0xFFCF142B); sub = 'Banco Central de Venezuela'; }
          else if (id == 'paralelo' || id == 'enparalelovzla') { c1 = const Color(0xFF0f5132); c2 = const Color(0xFF198754); sub = 'Monitor Dólar'; }
          else if (id == 'binance') { c1 = const Color(0xFFF3BA2F); c2 = const Color(0xFFF0B90B); sub = 'Mercado P2P'; }
          else if (id == 'paypal') { c1 = const Color(0xFF003087); c2 = const Color(0xFF0079C1); sub = 'Comisiones estimadas'; }
          
          fetchedRates.add(RateItem(id, name, rate, c1, c2, sub));
        }

        if (count > 0) avgRate = sum / count;
        
        // Cache data
        await prefs.setString('ratesCache', json.encode(data));
        isOnline = true;
      }
    } catch (e) {
      isOnline = false;
      // Load from cache if exists
      String? cached = prefs.getString('ratesCache');
      if (cached != null) {
        // Simple fallback
      }
    }

    if (mounted) {
      setState(() {
        rates = fetchedRates;
        if (rates.isNotEmpty) {
          currentRate = rates.firstWhere((r) => r.id == 'bcv', orElse: () => rates.first).rate;
          currentName = rates.firstWhere((r) => r.id == 'bcv', orElse: () => rates.first).name;
        }
        isLoading = false;
      });
      _calc('ves', vesController.text);
    }
  }

  void _calc(String source, String value) {
    if (value.isEmpty) {
      if (source != 'ves') vesController.text = '';
      if (source != 'usd') usdController.text = '';
      if (source != 'avg') usdAvgController.text = '';
      return;
    }

    double? val = double.tryParse(value);
    if (val == null) return;

    if (source == 'ves') {
      usdController.text = (val / currentRate).toStringAsFixed(2);
      usdAvgController.text = (val / avgRate).toStringAsFixed(2);
    } else if (source == 'usd') {
      double ves = val * currentRate;
      vesController.text = ves.toStringAsFixed(2);
      usdAvgController.text = (ves / avgRate).toStringAsFixed(2);
    } else if (source == 'avg') {
      double ves = val * avgRate;
      vesController.text = ves.toStringAsFixed(2);
      usdController.text = (ves / currentRate).toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
                      SizedBox(width: 10),
                      Text('DolarVE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 12, color: isOnline ? Colors.greenAccent : Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, color: isOnline ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: _loadData,
                        child: const Icon(Icons.refresh, color: Colors.grey),
                      )
                    ],
                  )
                ],
              ),
            ),

            // Calculator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CALCULADORA', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                        child: Text('Usando: $currentName (${currentRate.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildInput('Bolívares (VES)', 'Bs.', vesController, 'ves', Colors.white),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInput('USD ($currentName)', '\$', usdController, 'usd', Colors.greenAccent)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput('USD (Promedio)', '\$', usdAvgController, 'avg', Colors.purpleAccent)),
                    ],
                  )
                ],
              ),
            ),

            // Rates List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: rates.length,
                      itemBuilder: (context, index) {
                        final rate = rates[index];
                        final isSelected = currentName == rate.name;
                        final textColor = rate.id == 'binance' ? Colors.black : Colors.white;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              currentName = rate.name;
                              currentRate = rate.rate;
                            });
                            _calc('ves', vesController.text);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [rate.color1, rate.color2]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                              boxShadow: isSelected ? [const BoxShadow(color: Colors.white30, blurRadius: 10)] : [],
                            ),
                            foregroundDecoration: BoxDecoration(
                              color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rate.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                    const SizedBox(height: 4),
                                    Text(rate.subtitle, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8))),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(rate.rate.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor)),
                                    if (isSelected) ...[
                                      const SizedBox(width: 10),
                                      Icon(Icons.check_circle, color: textColor),
                                    ]
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, String prefix, TextEditingController controller, String source, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(prefix, style: TextStyle(fontSize: 18, color: color.withOpacity(0.7), fontWeight: FontWeight.bold)),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => _calc(source, val),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
