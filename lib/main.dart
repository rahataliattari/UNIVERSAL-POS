import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PosApp());

String fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

// ---------- Models ----------
class Product {
  String name;
  double price;
  int stock;
  Product(this.name, this.price, this.stock);
  Map<String, dynamic> toJson() =>
      {'name': name, 'price': price, 'stock': stock};
  factory Product.fromJson(Map<String, dynamic> j) => Product(
      j['name'] as String, (j['price'] as num).toDouble(), (j['stock'] as num).toInt());
}

class Sale {
  String date;
  double total;
  String items;
  Sale(this.date, this.total, this.items);
  Map<String, dynamic> toJson() =>
      {'date': date, 'total': total, 'items': items};
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
      j['date'] as String, (j['total'] as num).toDouble(), j['items'] as String);
}

class Shop {
  String name;
  List<Product> products;
  List<Sale> sales;
  Shop(this.name, [List<Product>? p, List<Sale>? s])
      : products = p ?? [],
        sales = s ?? [];
  Map<String, dynamic> toJson() => {
        'name': name,
        'products': products.map((e) => e.toJson()).toList(),
        'sales': sales.map((e) => e.toJson()).toList(),
      };
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        j['name'] as String,
        (j['products'] as List)
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        (j['sales'] as List)
            .map((e) => Sale.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ---------- Store ----------
class Store extends ChangeNotifier {
  List<Shop> shops = [];
  int current = 0;
  bool loaded = false;
  Shop get shop => shops[current];

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('data');
      if (s != null) {
        shops = (jsonDecode(s) as List)
            .map((e) => Shop.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    if (shops.isEmpty) shops = [Shop('میری دکان')];
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          'data', jsonEncode(shops.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}

final store = Store();

// ---------- App ----------
class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Universal POS',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        builder: (ctx, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const Home(),
      );
}

Future<List<String>?> askDialog(BuildContext c, String title,
    List<String> labels, List<String> initial, List<bool> numeric) {
  final ctrls = List.generate(
      labels.length, (i) => TextEditingController(text: initial[i]));
  return showDialog<List<String>>(
    context: c,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < labels.length; i++)
                TextField(
                  controller: ctrls[i],
                  decoration: InputDecoration(labelText: labels[i]),
                  keyboardType:
                      numeric[i] ? TextInputType.number : TextInputType.text,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('منسوخ')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrls.map((e) => e.text.trim()).toList()),
              child: const Text('محفوظ کریں')),
        ],
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final Map<int, int> cart = {}; // product index -> qty

  @override
  void initState() {
    super.initState();
    store.load();
  }

  void msg(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));

  double get cartTotal {
    double t = 0;
    cart.forEach((i, q) {
      if (i < store.shop.products.length) t += store.shop.products[i].price * q;
    });
    return t;
  }

  Future<void> addShop() async {
    final r = await askDialog(context, 'نئی دکان', ['دکان کا نام'], [''], [false]);
    if (r == null || r[0].isEmpty) return;
    store.shops.add(Shop(r[0]));
    store.current = store.shops.length - 1;
    cart.clear();
    await store.save();
  }

  Future<void> editProduct([int? index]) async {
    final p = index == null ? null : store.shop.products[index];
    final r = await askDialog(
      context,
      p == null ? 'نئی چیز' : 'چیز میں ترمیم',
      ['نام', 'قیمت', 'اسٹاک'],
      [p?.name ?? '', p == null ? '' : fmt(p.price), p?.stock.toString() ?? ''],
      [false, true, true],
    );
    if (r == null || r[0].isEmpty) return;
    final price = double.tryParse(r[1]) ?? 0;
    final stock = int.tryParse(r[2]) ?? 0;
    if (p == null) {
      store.shop.products.add(Product(r[0], price, stock));
    } else {
      p.name = r[0];
      p.price = price;
      p.stock = stock;
    }
    await store.save();
  }

  Future<void> checkout() async {
    if (cart.isEmpty) return;
    final names = <String>[];
    double total = 0;
    cart.forEach((i, q) {
      final p = store.shop.products[i];
      p.stock -= q;
      total += p.price * q;
      names.add('${p.name} × $q');
    });
    store.shop.sales.add(
        Sale(DateTime.now().toString().substring(0, 16), total, names.join('، ')));
    cart.clear();
    await store.save();
    msg('بل مکمل: ${fmt(total)} روپے');
  }

  // ----- Tabs -----
  Widget sellTab() {
    final products = store.shop.products;
    if (products.isEmpty) {
      return const Center(child: Text('پہلے "مصنوعات" میں چیزیں شامل کریں'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final p = products[i];
              final inCart = cart[i] ?? 0;
              return ListTile(
                title: Text(p.name),
                subtitle: Text('قیمت: ${fmt(p.price)}  |  اسٹاک: ${p.stock}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    if (inCart >= p.stock) {
                      msg('اسٹاک ختم');
                      return;
                    }
                    setState(() => cart[i] = inCart + 1);
                  },
                ),
              );
            },
          ),
        ),
        if (cart.isNotEmpty)
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in cart.entries)
                    Row(
                      children: [
                        Expanded(child: Text(products[e.key].name)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                            if (e.value <= 1) {
                              cart.remove(e.key);
                            } else {
                              cart[e.key] = e.value - 1;
                            }
                          }),
                        ),
                        Text('${e.value}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() {
                            if (e.value < products[e.key].stock) {
                              cart[e.key] = e.value + 1;
                            }
                          }),
                        ),
                        SizedBox(
                            width: 60,
                            child: Text(fmt(products[e.key].price * e.value))),
                      ],
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                          child: Text('کل: ${fmt(cartTotal)} روپے',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                      FilledButton(
                          onPressed: checkout, child: const Text('بل مکمل کریں')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget productsTab() {
    final products = store.shop.products;
    if (products.isEmpty) {
      return const Center(child: Text('نیچے + دبا کر چیز شامل کریں'));
    }
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        return ListTile(
          title: Text(p.name),
          subtitle: Text('قیمت: ${fmt(p.price)}  |  اسٹاک: ${p.stock}'),
          onTap: () => editProduct(i),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              store.shop.products.removeAt(i);
              cart.clear();
              await store.save();
            },
          ),
        );
      },
    );
  }

  Widget reportTab() {
    final sales = store.shop.sales.reversed.toList();
    final total = store.shop.sales.fold<double>(0, (a, s) => a + s.total);
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('کل فروخت: ${fmt(total)} روپے',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('بلوں کی تعداد: ${sales.length}'),
          ),
        ),
        Expanded(
          child: sales.isEmpty
              ? const Center(child: Text('ابھی کوئی فروخت نہیں'))
              : ListView.builder(
                  itemCount: sales.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text('${fmt(sales[i].total)} روپے'),
                    subtitle: Text('${sales[i].date}\n${sales[i].items}'),
                    isThreeLine: true,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (ctx, _) {
        if (!store.loaded) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final pages = [sellTab(), productsTab(), reportTab()];
        return Scaffold(
          appBar: AppBar(
            title: PopupMenuButton<int>(
              onSelected: (i) => setState(() {
                store.current = i;
                cart.clear();
                store.save();
              }),
              itemBuilder: (_) => [
                for (int i = 0; i < store.shops.length; i++)
                  PopupMenuItem(value: i, child: Text(store.shops[i].name)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(store.shop.name),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            actions: [
              IconButton(
                  tooltip: 'نئی دکان',
                  icon: const Icon(Icons.add_business),
                  onPressed: addShop),
            ],
          ),
          body: pages[tab],
          floatingActionButton: tab == 1
              ? FloatingActionButton(
                  onPressed: () => editProduct(), child: const Icon(Icons.add))
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'بل'),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2), label: 'مصنوعات'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'رپورٹ'),
            ],
          ),
        );
      },
    );
  }
}
