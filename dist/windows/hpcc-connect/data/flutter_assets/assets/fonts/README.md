# Font Directory

This directory should contain the JetBrains Mono font for optimal terminal rendering.

## Download Instructions

1. Visit https://www.jetbrains.com/lp/mono/
2. Download the font family
3. Extract and copy `JetBrainsMono-Regular.ttf` to this directory

Alternatively, you can download directly:
```bash
curl -L -o JetBrainsMono.zip https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip
unzip JetBrainsMono.zip -d temp
cp temp/fonts/ttf/JetBrainsMono-Regular.ttf .
rm -rf temp JetBrainsMono.zip
```

Note: The app will work without this font, but terminal text may not render as nicely.
