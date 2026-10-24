import 'package:intl/intl.dart';

import 'models.dart';

/// Largest accepted weight (grams), amount, rate and unit count.
const maxGrams = 1000000.0;
const maxMoney = 10000000.0;
const maxUnits = 100000.0;

String currencySymbol = '₹';

String money(double value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: currencySymbol,
  decimalDigits: value == value.roundToDouble() ? 0 : 2,
).format(value);

/// Always two decimals, for invoices and totals.
String money2(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: currencySymbol, decimalDigits: 2).format(value);

String _trimmed(double value, int maxDecimals) {
  final pattern = maxDecimals == 0 ? '#,##0' : '#,##0.${'#' * maxDecimals}';
  return NumberFormat(pattern, 'en_IN').format(value);
}

String grams(double g) => '${_trimmed(g, 2)} g';

String kg(double g) => '${_trimmed(g / 1000, 3)} kg';

/// "8.8 kg (8,800 g)" or "250 g" for smaller weights.
String weight(double g) => g >= 1000 ? '${kg(g)} / ${grams(g)}' : '${grams(g)} / ${kg(g)}';

String units(double count, String label) {
  final text = _trimmed(count, 3);
  return '$text ${count == 1 ? label : _plural(label)}';
}

String _plural(String label) {
  if (label.isEmpty || label.endsWith('s')) return label;
  if (label.endsWith('x')) return '${label}es';
  return '${label}s';
}

/// Plain number for prefilling text fields: no grouping, no trailing zeros.
String editable(double value, {int maxDecimals = 3}) {
  final text = value.toStringAsFixed(maxDecimals);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

double? parseNumber(String text) {
  final value = double.tryParse(text.replaceAll(',', '').trim());
  return value != null && value.isFinite ? value : null;
}

/// Digits with country code for WhatsApp links, e.g. "919876543210".
/// A bare 10-digit number is treated as an Indian number. Returns null
/// when the input cannot be a valid international phone number.
String? normalisePhone(String text) {
  var digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) digits = '91$digits';
  return digits.length >= 11 && digits.length <= 15 ? digits : null;
}

/// "+91 98765 43210" style display for a normalised number.
String displayPhone(String normalised) => '+$normalised';

String rateLabel(BillLine line) => switch (line.mode) {
  LineMode.weight || LineMode.amount => (line.appliedRate ?? 0) > 0 ? '${money(line.appliedRate!)}/kg' : '—',
  LineMode.unit => '${money(line.appliedRate ?? 0)}/${line.unitLabel ?? 'unit'}',
  LineMode.amountOnly => '—',
};

String quantityLabel(BillLine line) => switch (line.mode) {
  LineMode.weight => weight(line.grams ?? 0),
  LineMode.amount => line.grams == null ? 'Amount only' : 'approx. ${weight(line.grams!)}',
  LineMode.unit => units(line.units ?? 0, line.unitLabel ?? 'unit'),
  LineMode.amountOnly => line.note?.isNotEmpty == true ? line.note! : 'Amount only',
};

String modeLabel(LineMode mode) => switch (mode) {
  LineMode.weight => 'By weight',
  LineMode.amount => 'By amount',
  LineMode.unit => 'By unit',
  LineMode.amountOnly => 'Amount only',
};

String productRateLabel(Product product) => switch (product.mode) {
  ProductMode.weight => product.ratePerKg > 0 ? '${money(product.ratePerKg)}/kg' : 'Rate at billing',
  ProductMode.unit => '${money(product.unitPrice)}/${product.unitLabel}',
  ProductMode.amountOnly => 'Enter amount',
};

/// "10% off", "₹20 off", "50 g free" or "1 piece free"; empty without a discount.
String lineDiscountLabel(BillLine line) => switch (line.discountType) {
  LineDiscountType.none => '',
  LineDiscountType.percent => '${editable(line.discountValue, maxDecimals: 2)}% off',
  LineDiscountType.fixed => '${money(line.discountValue)} off',
  LineDiscountType.quantity =>
    line.mode == LineMode.unit
        ? '${units(line.discountValue, line.unitLabel ?? 'unit')} free'
        : '${grams(line.discountValue)} free',
};

/// Rows shown above the grand total on every bill view. Without discounts
/// this is just the subtotal; with them it shows actual, discounts and the
/// amount after discount.
List<({String label, String value, bool discount})> billSummary(Bill bill) {
  final billDiscountLabel = bill.discountType == DiscountType.percent
      ? 'Bill discount (${editable(bill.discountValue, maxDecimals: 2)}%)'
      : 'Bill discount';
  return [
    if (bill.totalDiscount > 0) ...[
      (label: 'Actual amount', value: money2(bill.itemsTotal), discount: false),
      if (bill.itemDiscount > 0)
        (label: 'Item discounts', value: '- ${money2(bill.itemDiscount)}', discount: true),
      if (bill.discountAmount > 0)
        (label: billDiscountLabel, value: '- ${money2(bill.discountAmount)}', discount: true),
      if (bill.itemDiscount > 0 && bill.discountAmount > 0)
        (label: 'Total discount', value: '- ${money2(bill.totalDiscount)}', discount: true),
      (label: 'After discount', value: money2(bill.afterDiscount), discount: false),
    ],
    if (bill.taxName != null)
      (
        label: '${bill.taxName} (${editable(bill.taxPercent)}%)',
        value: money2(bill.taxAmount),
        discount: false,
      ),
  ];
}

String dateTime(DateTime value) => DateFormat('dd MMM yyyy, hh:mm a').format(value);

String date(DateTime value) => DateFormat('dd MMM yyyy').format(value);

/// Billing maths kept separate from widgets so it can be unit tested.
class Calc {
  static double weightAmount(double grams, double ratePerKg) => roundMoney(grams / 1000 * ratePerKg);

  /// Estimated grams for a rupee amount, or null when no usable rate exists.
  static double? gramsForAmount(double amount, double ratePerKg) =>
      ratePerKg > 0 ? amount / ratePerKg * 1000 : null;

  static double unitAmount(double count, double unitPrice) => roundMoney(count * unitPrice);
}
