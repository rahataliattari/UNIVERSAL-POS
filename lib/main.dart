import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWebNoWebWorker;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }
  runApp(const UniversalPOS());
}

// ---------------- ڈیٹابیس ----------------
class Db {
  static Database? _db;
  static int _n = 0;

  static String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_n++}';

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'universal_pos.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (d, v) async {
        await d.execute(
            'CREATE TABLE products(id TEXT PRIMARY KEY, name TEXT, price REAL, stock INTEGER, synced INTEGER DEFAULT 0)');
        await d.execute(
            'CREATE TABLE sales(id TEXT PRIMARY KEY, total REAL, created_at TEXT, synced INTEGER DEFAULT 0)');
        await d.execute(
            'CREATE TABLE sale_items(id TEXT PRIMARY KEY, sale_id TEXT, product_id TEXT, name TEXT, price REAL, qty INTEGER)');
        await d.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return _db!;
  }

  static Future<String> getSetting(String key, String def) async {
    final d = await db;
    final r = await d.query('settings', where: 'key = ?', whereArgs: [key]);
    if (r.isEmpty) return def;
    return r.first['value'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

String money(num v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// ---------------- ایپ ----------------
class UniversalPOS extends StatelessWidget {
  const UniversalPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Universal POS',
      locale: const Locale('ur'),
      supportedLocales: const [Locale('ur'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------- ہوم ----------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String shop = '';

  @override
  void initState() {
    super.initState();
    loadShop();
  }

  Future<void> loadShop() async {
    final s = await Db.getSetting('shop_name', '');
    if (!mounted) return;
    setState(() => shop = s);
  }

  Future<void> open(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    loadShop();
  }

  Widget tile(IconData icon, String title, Widget screen) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => open(screen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.isEmpty ? 'یونیورسل POS' : shop),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('خوش آمدید!',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          tile(Icons.inventory_2, 'پروڈکٹس', const ProductsScreen()),
          tile(Icons.point_of_sale, 'نئی سیل / بلنگ', const BillingScreen()),
          tile(Icons.receipt_long, 'بل ہسٹری', const HistoryScreen()),
          tile(Icons.bar_chart, 'سیلز رپورٹ', const ReportScreen()),
          tile(Icons.settings, 'سیٹنگز', const SettingsScreen()),
        ],
      ),
    );
  }
}

// ---------------- پروڈکٹس ----------------
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await Db.db;
    final r = await d.query('products', orderBy: 'name');
    if (!mounted) return;
    setState(() => items = r);
  }

  Future<void> edit([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: (item?['name'] as String?) ?? '');
    final price =
        TextEditingController(text: item == null ? '' : '${item['price']}');
    final stock =
        TextEditingController(text: item == null ? '' : '${item['stock']}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item == null ? 'نیا پروڈکٹ' : 'پروڈکٹ ایڈٹ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'نام')),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قیمت')),
            TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'اسٹاک')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('منسوخ')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('محفوظ')),
        ],
      ),
    );

    if (ok != true || name.text.trim().isEmpty) return;
    final d = await Db.db;
    final values = <String, Object?>{
      'name': name.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'stock': int.tryParse(stock.text) ?? 0,
      'synced': 0,
    };
    if (item == null) {
      await d.insert('products', {'id': Db.newId(), ...values});
    } else {
      await d.update('products', values,
          where: 'id = ?', whereArgs: [item['id']]);
    }
    load();
  }

  Future<void> remove(Map<String, Object?> item) async {
    final d = await Db.db;
    await d.delete('products', where: 'id = ?', whereArgs: [item['id']]);
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پروڈکٹس')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const Center(child: Text('کوئی پروڈکٹ نہیں۔ + دبا کر شامل کریں'))
          : ListView(
              children: [
                for (final i in items)
                  ListTile(
                    title: Text('${i['name']}'),
                    subtitle: Text(
                        'قیمت: ${money(i['price'] as num)}  |  اسٹاک: ${i['stock']}'),
                    onTap: () => edit(i),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => remove(i),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------- بلنگ ----------------
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Map<String, Object?>> items = [];
  final Map<String, int> cart = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await Db.db;
    final r = await d.query('products', orderBy: 'name');
    if (!mounted) return;
    setState(() => items = r);
  }

  double get total {
    double t = 0;
    for (final i in items) {
      final q = cart[i['id'] as String] ?? 0;
      t += q * (i['price'] as num).toDouble();
    }
    return t;
  }

  void add(Map<String, Object?> i) {
    final id = i['id'] as String;
    final q = cart[id] ?? 0;
    if (q >= (i['stock'] as int)) return;
    setState(() => cart[id] = q + 1);
  }

  void sub(Map<String, Object?> i) {
    final id = i['id'] as String;
    final q = cart[id] ?? 0;
    if (q <= 0) return;
    setState(() {
      if (q == 1) {
        cart.remove(id);
      } else {
        cart[id] = q - 1;
      }
    });
  }

  Future<void> save() async {
    if (cart.isEmpty) return;
    final d = await Db.db;
    final saleId = Db.newId();
    final sum = total;
    await d.transaction((t) async {
      await t.insert('sales', {
        'id': saleId,
        'total': sum,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });
      for (final i in items) {
        final id = i['id'] as String;
        final q = cart[id] ?? 0;
        if (q == 0) continue;
        await t.insert('sale_items', {
          'id': Db.newId(),
          'sale_id': saleId,
          'product_id': id,
          'name': i['name'],
          'price': i['price'],
          'qty': q,
        });
        await t.rawUpdate(
            'UPDATE products SET stock = stock - ?, synced = 0 WHERE id = ?',
            [q, id]);
      }
    });
    cart.clear();
    await load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('بل محفوظ ہو گیا')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نئی سیل / بلنگ')),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('پہلے پروڈکٹس شامل کریں'))
                : ListView(
                    children: [
                      for (final i in items)
                        ListTile(
                          title: Text('${i['name']}'),
                          subtitle: Text(
                              'قیمت: ${money(i['price'] as num)}  |  اسٹاک: ${i['stock']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => sub(i)),
                              Text('${cart[i['id'] as String] ?? 0}',
                                  style: const TextStyle(fontSize: 18)),
                              IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => add(i)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border(top: BorderSide(color: Colors.green.shade200)),
              ),
              child: Row(
                children: [
                  Text('کل: ${money(total)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton(
                    onPressed: cart.isEmpty ? null : save,
                    child: const Text('بل محفوظ کریں'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- بل ہسٹری ----------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, Object?>> sales = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await Db.db;
    final r = await d.query('sales', orderBy: 'created_at DESC');
    if (!mounted) return;
    setState(() => sales = r);
  }

  String when(Object? iso) =>
      (iso as String).substring(0, 16).replaceFirst('T', '  ');

  Future<void> show(Map<String, Object?> sale) async {
    final d = await Db.db;
    final rows = await d
        .query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('بل: ${money(sale['total'] as num)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Text(
                    '${r['name']} × ${r['qty']} = ${money((r['price'] as num) * (r['qty'] as num))}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('بند کریں')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بل ہسٹری')),
      body: sales.isEmpty
          ? const Center(child: Text('ابھی کوئی بل نہیں'))
          : ListView(
              children: [
                for (final s in sales)
                  ListTile(
                    leading: const Icon(Icons.receipt, color: Colors.green),
                    title: Text(money(s['total'] as num)),
                    subtitle: Text(when(s['created_at'])),
                    onTap: () => show(s),
                  ),
              ],
            ),
    );
  }
}

// ---------------- سیلز رپورٹ ----------------
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int todayCount = 0, allCount = 0;
  double todaySum = 0, allSum = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await Db.db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final t = await d.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(total),0) s FROM sales WHERE created_at >= ?',
        [start]);
    final a = await d
        .rawQuery('SELECT COUNT(*) c, COALESCE(SUM(total),0) s FROM sales');
    if (!mounted) return;
    setState(() {
      todayCount = t.first['c'] as int;
      todaySum = (t.first['s'] as num).toDouble();
      allCount = a.first['c'] as int;
      allSum = (a.first['s'] as num).toDouble();
    });
  }

  Widget card(String title, int count, double sum) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('بلوں کی تعداد: $count'),
            Text('کل سیل: ${money(sum)}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سیلز رپورٹ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card('آج', todayCount, todaySum),
          card('اب تک', allCount, allSum),
        ],
      ),
    );
  }
}

// ---------------- سیٹنگز ----------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();

  @override
  void initState() {
    super.initState();
    Db.getSetting('shop_name', '').then((v) {
      if (mounted) name.text = v;
    });
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    await Db.setSetting('shop_name', name.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('محفوظ ہو گیا')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سیٹنگز')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'دوکان کا نام')),
            const SizedBox(height: 16),
            FilledButton(onPressed: save, child: const Text('محفوظ کریں')),
            const SizedBox(height: 24),
            const Text('آن لائن سنک: جلد شامل ہوگا',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
