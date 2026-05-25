from PIL import Image
import sys

img_path = sys.argv[1]
img = Image.open(img_path).convert("RGBA")
datas = img.getdata()

newData = []
for item in datas:
    # If the pixel is very dark (close to black), make it transparent
    # r, g, b, a = item
    if item[0] < 20 and item[1] < 20 and item[2] < 20:
        newData.append((255, 255, 255, 0)) # transparent
    else:
        newData.append(item)

img.putdata(newData)
img.save(img_path, "PNG")
print("Done")
