from pathlib import Path
path = Path('lib/utils/payment/bank_transfer_screen.dart')
data = path.read_bytes()
print('len', len(data))
print('first bytes', data[:8])
