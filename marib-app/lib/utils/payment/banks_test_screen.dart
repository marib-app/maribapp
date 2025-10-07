/*
import 'package:flutter/material.dart';
import 'bank_api.dart';
import 'bank_account.dart';

class BanksTestScreen extends StatefulWidget {
  const BanksTestScreen({super.key});

  static Route route() => MaterialPageRoute(builder: (_) => const BanksTestScreen());

  @override
  State<BanksTestScreen> createState() => _BanksTestScreenState();
}

class _BanksTestScreenState extends State<BanksTestScreen> {
  late Future<List<BankAccount>> _future;

  @override
  void initState() {
    super.initState();
    _future = BankApi().fetchBanks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات البنكية')),
      body: FutureBuilder<List<BankAccount>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          final banks = snap.data ?? [];
          if (banks.isEmpty) {
            return const Center(child: Text('لا توجد حسابات بنكية مفعلة'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: banks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = banks[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (b.logoUrl != null && b.logoUrl!.isNotEmpty)
                      ? NetworkImage(b.logoUrl!)
                      : null,
                  child: (b.logoUrl == null || b.logoUrl!.isEmpty)
                      ? const Icon(Icons.account_balance)
                      : null,
                ),
                title: Text(b.bankName),
                subtitle: Text('${b.accountName} • ${b.accountNumber}${b.iban != null ? ' • IBAN: ${b.iban}' : ''}'),
                trailing: Chip(
                  label: Text(b.isActive ? 'مفعل' : 'معطل'),
                  backgroundColor: b.isActive ? Colors.green.shade100 : Colors.grey.shade300,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

 */
