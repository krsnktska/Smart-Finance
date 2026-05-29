import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/transaction_model.dart';
import 'package:mobile/providers/categories_provider.dart';
import 'package:mobile/providers/transactions_provider.dart';
import 'package:mobile/widgets/app_buttons.dart';
import 'package:mobile/widgets/app_text_field.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String accountId;
  final String currency;
  final TransactionModel? transaction;

  const TransactionFormScreen({
    super.key,
    required this.accountId,
    required this.currency,
    this.transaction,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TransactionType _type;
  SpecialType? _specialType;
  late double _value;
  late DateTime _occurredAt;
  late String _name;
  String? _description;
  final List<String> _selectedCategoryIds = [];

  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _type = tx.type;
      _specialType = tx.specialType;
      _value = tx.value;
      _occurredAt = tx.occurredAt;
      _name = tx.name;
      _description = tx.description;
      _selectedCategoryIds.addAll(tx.categories.map((c) => c.id));

      _nameController.text = _name;
      _valueController.text = _value.toString();
      _descriptionController.text = _description ?? '';
    } else {
      _type = TransactionType.expense;
      _specialType = null;
      _value = 0.0;
      _occurredAt = DateTime.now();
      _name = '';
      _description = '';
    }

    Future.microtask(() {
      ref.read(categoriesProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (pickedTime == null) return;

    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final notifier = ref.read(transactionsProvider(widget.accountId).notifier);

    final value = double.tryParse(_valueController.text) ?? 0.0;
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();

    final dateUtc = _occurredAt.toUtc();

    bool success;
    if (widget.transaction != null) {
      success = await notifier.updateTransaction(
        transactionId: widget.transaction!.id,
        type: _type,
        specialType: _specialType,
        value: value,
        occurredAt: dateUtc,
        name: name,
        description: desc.isEmpty ? null : desc,
        currency: widget.currency,
        categoryIds: _selectedCategoryIds,
      );
    } else {
      success = await notifier.createTransaction(
        type: _type,
        specialType: _specialType,
        value: value,
        occurredAt: dateUtc,
        name: name,
        description: desc.isEmpty ? null : desc,
        currency: widget.currency,
        categoryIds: _selectedCategoryIds,
      );
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.transaction != null
                ? 'Transaction updated'
                : 'Transaction added',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final error = ref.read(transactionsProvider(widget.accountId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to save transaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final isEdit = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Type Selection (Income vs Expense)
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.arrow_upward,
                            color: Colors.red,
                          ),
                          label: const Text('Expense'),
                          selected: _type == TransactionType.expense,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _type = TransactionType.expense);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.arrow_downward,
                            color: Colors.green,
                          ),
                          label: const Text('Income'),
                          selected: _type == TransactionType.income,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _type = TransactionType.income);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Value Field
                  AppTextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    labelText: 'Amount (${widget.currency})',
                    prefixIcon: const Icon(Icons.attach_money),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter amount';
                      }
                      final numVal = double.tryParse(val);
                      if (numVal == null || numVal <= 0) {
                        return 'Please enter a positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _nameController,
                    labelText: 'Title / Recipient',
                    prefixIcon: const Icon(Icons.title),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _descriptionController,
                    labelText: 'Description (optional)',
                    prefixIcon: const Icon(Icons.description),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Occurred At Date Picker
                  ListTile(
                    title: const Text('Date & Time'),
                    subtitle: Text(
                      '${_occurredAt.day.toString().padLeft(2, '0')}.${_occurredAt.month.toString().padLeft(2, '0')}.${_occurredAt.year} ${_occurredAt.hour.toString().padLeft(2, '0')}:${_occurredAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    onTap: _selectDateTime,
                  ),
                  const SizedBox(height: 20),

                  // Special Type Selector
                  DropdownButtonFormField<SpecialType?>(
                    initialValue: _specialType,
                    decoration: InputDecoration(
                      labelText: 'Special Type',
                      prefixIcon: const Icon(Icons.star),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<SpecialType?>(
                        value: null,
                        child: Text('Regular (None)'),
                      ),
                      ...SpecialType.values.map((type) {
                        return DropdownMenuItem<SpecialType?>(
                          value: type,
                          child: Text(
                            type.toString().split('.').last.toUpperCase(),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _specialType = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Categories Selection Label
                  const Text(
                    'Select Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Category Chips Selector
                  categoriesState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : categoriesState.categories.isEmpty
                      ? const Text(
                          'No categories available. Please create categories first on the Categories tab.',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categoriesState.categories.map((cat) {
                            final isSelected = _selectedCategoryIds.contains(
                              cat.id,
                            );
                            return FilterChip(
                              avatar: cat.emoji != null
                                  ? Text(cat.emoji!)
                                  : null,
                              label: Text(cat.name),
                              selected: isSelected,
                              selectedColor: cat.categoryColor.withValues(
                                alpha: 0.3,
                              ),
                              checkmarkColor: cat.categoryColor,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(cat.id);
                                  } else {
                                    _selectedCategoryIds.remove(cat.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 40),

                  // Save Button
                  AppButton(
                    label: isEdit ? 'Save Changes' : 'Create Transaction',
                    onPressed: _saveTransaction,
                  ),
                ],
              ),
            ),
    );
  }
}
