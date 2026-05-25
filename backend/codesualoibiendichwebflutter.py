import os
replacements = {
    '7195426469378571114': '7195426469378571264',
    '8781752057772026410': '8781752057772026880',
    '5151902556644193383': '5151902556644193280',
    '3433535483987302584': '3433535483987302400',
    '408305115005495918': '408305115005495936',
    '7560358558326323820': '7560358558326324224',
    '2850616322253582584': '2850616322253582336',
    '5597269249152036073': '5597269249152035840',
    '8655055437920518966': '8655055437920519168',
    '2859712421507225249': '2859712421507225088',
    '7496997594039063869': '7496997594039063552',
    '3156591011457686752': '3156591011457686528',
    '3525046097552820205': '3525046097552820224',
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