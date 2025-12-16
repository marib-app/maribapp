from pathlib import Path
path=Path(r"marib-app/lib/ui/screens/item/ad_details_screen/ad_details_screen.dart")
text=path.read_text(encoding="utf-8", errors="replace")
marker="Future<void> _showCartTipBottomSheet"
start=text.find(marker)
print('start', start)
if start==-1:
    raise SystemExit(1)
brace_start=text.find('{', start)
print('brace', brace_start)
if brace_start==-1:
    raise SystemExit(2)
depth=0; end=None
for i,ch in enumerate(text[brace_start:], start=brace_start):
    if ch=='{': depth+=1
    elif ch=='}':
        depth-=1
        if depth==0:
            end=i; break
print('end', end)
