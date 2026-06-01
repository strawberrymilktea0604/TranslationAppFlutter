import os
replacements = {
    '7195426469378571114': '((1675315776 << 32) + 985709418)',
    '8781752057772026410': '((2044660984 << 32) + 84847146)',
    '5151902556644193383': '((1199520788 << 32) + 1312044135)',
    '3433535483987302584': '((799432276 << 32) + 3200456888)',
    '408305115005495918': '((95065942 << 32) + 3152063086)',
    '7560358558326323820': '((1760283149 << 32) + 1671428716)',
    '2850616322253582584': '((663710833 << 32) + 517665016)',
    '5597269249152036073': '((1303215801 << 32) + 4226591977)',
    '8655055437920518966': '((2015162128 << 32) + 2022753078)',
    '2859712421507225249': '((665828683 << 32) + 3283474081)',
    '7496997594039063869': '((1745530775 << 32) + 1252529469)',
    '3156591011457686752': '((734951116 << 32) + 4078984416)',
    '3525046097552820205': '((820738751 << 32) + 3447932909)',
    '5633630139823007711': '((1311681731 << 32) + 2417338335)',
}

base_dir = r'c:\Users\minhk\Downloads\TranslationAppFlutter\frontend\lib'
count = 0
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.g.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            modified = False
            for old, new in replacements.items():
                if old in content:
                    content = content.replace(old, new)
                    modified = True
            
            if modified:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                count += 1
                print(f'Patched {filepath}')

print(f'Total files patched: {count}')
