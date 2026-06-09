import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/models/receipt_item_model.dart';
import 'package:mobile/models/receipt_scan_model.dart';
import 'package:mobile/models/transaction_model.dart';
import 'package:mobile/providers/categories_provider.dart';
import 'package:mobile/providers/receipt_provider.dart';
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
  bool _isScanningReceipt = false;
  String? _scannedTransactionId;
  final Set<String> _aiSuggestedCategoryIds = {};
  final List<ReceiptItemModel> _scannedItems = [];

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
      _scannedTransactionId = tx.id;

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
      _scannedTransactionId = null;
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

    setState(() => _isSaving = true);

    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(transactionsProvider(widget.accountId).notifier);

    final value = double.tryParse(_valueController.text) ?? 0.0;
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();

    final dateUtc = _occurredAt.toUtc();

    bool success;
    final transactionId = widget.transaction?.id ?? _scannedTransactionId;
    if (transactionId != null) {
      success = await notifier.updateTransaction(
        transactionId: transactionId,
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
          backgroundColor: cs.primary,
        ),
      );
      Navigator.pop(context, _scannedTransactionId != null);
    } else {
      final error = ref.read(transactionsProvider(widget.accountId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to save transaction'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<String> _fixCameraOrientation(String originalPath) async {
    try {
      final bytes = await File(originalPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return originalPath;

      final baked = img.bakeOrientation(decoded);

      final dir = File(originalPath).parent.path;
      final tmpPath =
          '$dir/receipt_norm_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tmpPath).writeAsBytes(img.encodeJpg(baked, quality: 92));
      return tmpPath;
    } catch (_) {
      return originalPath;
    }
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final cs = Theme.of(context).colorScheme;
    final isCamera = source == ImageSource.camera;
    final pickedImage = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: isCamera ? 1600 : null,
      maxHeight: isCamera ? 2200 : null,
    );
    if (pickedImage == null) return;

    setState(() => _isScanningReceipt = true);

    try {
      final uploadPath = isCamera
          ? await _fixCameraOrientation(pickedImage.path)
          : pickedImage.path;

      final scanResult = await ref
          .read(receiptRepositoryProvider)
          .scanReceipt(accountId: widget.accountId, imagePath: uploadPath);
      final suspiciousAmount = _populateFromScan(scanResult);

      if (mounted) {
        if (suspiciousAmount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Receipt scanned, but the amount looks incorrect — please enter it manually.',
              ),
              backgroundColor: cs.tertiary,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Receipt scanned. Review the transaction before saving.',
              ),
              backgroundColor: cs.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt scan failed: ${e.toString()}'),
            backgroundColor: cs.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningReceipt = false);
    }
  }

  Future<void> _showReceiptSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      await _scanReceipt(source);
    }
  }

  Future<void> _showReceiptUrlDialog() async {
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt URL'),
        content: TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Enter receipt URL',
            hintText: 'https://example.com/receipt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = urlController.text.trim();
              Navigator.pop(context, value.isEmpty ? null : value);
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      await _scanReceiptFromUrl(url);
    }
  }

  Future<void> _scanReceiptFromUrl(String url) async {
    final cs = Theme.of(context).colorScheme;
    setState(() => _isScanningReceipt = true);

    try {
      final scanResult = await ref
          .read(receiptRepositoryProvider)
          .scrapeReceipt(accountId: widget.accountId, url: url);
      final suspiciousAmount = _populateFromScan(scanResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              suspiciousAmount
                  ? 'Receipt scanned, but the amount looks incorrect — please enter it manually.'
                  : 'Receipt scanned from URL. Review the transaction before saving.',
            ),
            backgroundColor: suspiciousAmount ? cs.tertiary : cs.primary,
            duration: Duration(seconds: suspiciousAmount ? 5 : 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt scan failed: ${e.toString()}'),
            backgroundColor: cs.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningReceipt = false);
    }
  }

  Future<void> _showDiscardDialog() async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard scanned transaction?'),
        content: const Text(
          'A transaction was created from this scan. '
          'Do you want to keep it or delete it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == true) {
      await ref
          .read(transactionsProvider(widget.accountId).notifier)
          .deleteTransaction(_scannedTransactionId!);
      if (mounted) Navigator.pop(context, false);
    } else {
      Navigator.pop(context, true);
    }
  }

  bool _populateFromScan(ReceiptScanModel scan) {
    final tx = scan.transaction;
    final categoryIds = tx.categories.map((c) => c.id).toList();

    final isSuspiciousAmount = tx.value > 1000000;

    setState(() {
      _scannedTransactionId = tx.id;
      _type = tx.type;
      _specialType = tx.specialType;
      _occurredAt = tx.occurredAt;
      _nameController.text = tx.name;
      _valueController.text = isSuspiciousAmount ? '' : tx.value.toString();
      _descriptionController.text = tx.description ?? '';
      _selectedCategoryIds
        ..clear()
        ..addAll(categoryIds);
      _aiSuggestedCategoryIds
        ..clear()
        ..addAll(categoryIds);
      _scannedItems
        ..clear()
        ..addAll(scan.items);
    });

    return isSuspiciousAmount;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final isEdit = widget.transaction != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_scannedTransactionId != null && widget.transaction == null) {
            _showDiscardDialog();
          } else {
            Navigator.pop(context, false);
          }
        }
      },
      child: Scaffold(
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
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.arrow_upward,
                              color: Theme.of(context).colorScheme.error,
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
                            avatar: Icon(
                              Icons.arrow_downward,
                              color: Theme.of(context).colorScheme.primary,
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

                    if (widget.transaction == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isScanningReceipt
                                ? null
                                : _showReceiptSourcePicker,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              _isScanningReceipt
                                  ? 'Scanning receipt...'
                                  : 'Upload receipt',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _isScanningReceipt
                                ? null
                                : _showReceiptUrlDialog,
                            icon: const Icon(Icons.link),
                            label: const Text('Scan receipt from URL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_scannedTransactionId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _aiSuggestedCategoryIds.isNotEmpty
                                          ? 'Receipt scanned. AI suggested ${_aiSuggestedCategoryIds.length} ${_aiSuggestedCategoryIds.length == 1 ? 'category' : 'categories'}. Review before saving.'
                                          : 'Receipt scanned. Review and save.',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                    if (_scannedItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Receipt items (${_scannedItems.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          initiallyExpanded: true,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _scannedItems.asMap().entries.map((
                                  entry,
                                ) {
                                  final i = entry.key;
                                  final item = entry.value;
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'
                                              '${item.unit != null ? ' ${item.unit}' : ''}'
                                              ' × ${item.unitPrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              item.totalPrice.toStringAsFixed(
                                                2,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (i < _scannedItems.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 12,
                                          endIndent: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.2),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ],

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

                    ListTile(
                      title: const Text('Date & Time'),
                      subtitle: Text(
                        '${_occurredAt.day.toString().padLeft(2, '0')}.${_occurredAt.month.toString().padLeft(2, '0')}.${_occurredAt.year} ${_occurredAt.hour.toString().padLeft(2, '0')}:${_occurredAt.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: _selectDateTime,
                    ),
                    const SizedBox(height: 20),

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

                    const Text(
                      'Select Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    categoriesState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : categoriesState.categories.isEmpty
                        ? Text(
                            'No categories available. Please create categories first on the Categories tab.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categoriesState.categories.map((cat) {
                              final isSelected = _selectedCategoryIds.contains(
                                cat.id,
                              );
                              final isAiSuggested =
                                  _aiSuggestedCategoryIds.contains(cat.id) &&
                                  isSelected;
                              return FilterChip(
                                avatar: cat.emoji != null
                                    ? Text(cat.emoji!)
                                    : null,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cat.name),
                                    if (isAiSuggested) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 11,
                                        color: cat.categoryColor,
                                      ),
                                    ],
                                  ],
                                ),
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

                    AppButton(
                      label: isEdit ? 'Save Changes' : 'Create Transaction',
                      onPressed: _saveTransaction,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
