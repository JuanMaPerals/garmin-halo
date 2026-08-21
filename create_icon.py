from PIL import Image
img = Image.new('RGBA', (86, 86), (0, 80, 160, 255))
img.save('resources/drawables/launcher_icon.png')
print('Launcher icon created')
