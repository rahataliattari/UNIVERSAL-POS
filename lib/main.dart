
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const UniversalPOS());
}

class UniversalPOS extends StatelessWidget {
  const UniversalPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Universal POS',
      locale: const Locale('ur'),
      supportedLocales: const [
        Locale('ur'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('یونیورسل POS'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'خوش آمدید!',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              dashboardTile(
                Icons.inventory_2,
                'پروڈکٹس',
              ),
              dashboardTile(
                Icons.point_of_sale,
                'نئی سیل / بلنگ',
              ),
              dashboardTile(
                Icons.receipt_long,
                'بل ہسٹری',
              ),
              dashboardTile(
                Icons.bar_chart,
                'سیلز رپورٹ',
              ),
              dashboardTile(
                Icons.settings,
                'سیٹنگز',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dashboardTile(IconData icon, String title) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        trailing: const Icon(Icons.arrow_back_ios),
      ),
    );
  }
}
