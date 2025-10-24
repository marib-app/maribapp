import 'dart:io';

class ManualTransferSubmissionData {
  const ManualTransferSubmissionData({
    required this.senderName,
    required this.transferCode,
    this.note,
    this.receiptFile,
  });

  final String senderName;
  final String transferCode;
  final String? note;
  final File? receiptFile;

  String get trimmedSenderName => senderName.trim();

  String get trimmedTransferCode => transferCode.trim();

  String? get trimmedNote {
    final String? candidate = note;
    if (candidate == null) {
      return null;
    }
    final String normalized = candidate.trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool get hasReceipt => receiptFile != null;
}