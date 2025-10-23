import 'dart:io';

class ManualTransferSubmissionData {
  const ManualTransferSubmissionData({
    required this.senderName,
    required this.transferCode,
    this.receiptFile,
  });

  final String senderName;
  final String transferCode;
  final File? receiptFile;

  String get trimmedSenderName => senderName.trim();

  String get trimmedTransferCode => transferCode.trim();

  bool get hasReceipt => receiptFile != null;
}