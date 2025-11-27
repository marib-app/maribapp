from pathlib import Path
path = Path('lib/utils/payment/bank_transfer_screen.dart')
lines = path.read_text(encoding='utf-8', errors='ignore').splitlines()
print('len', len(lines))
for idx in range(1034, 1040):
    print(idx+1, repr(lines[idx]))
