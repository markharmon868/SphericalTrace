from PIL import Image
import numpy as np

def sum_image_values(image_path, u_max_step):
    # Load image in grayscale
    img = Image.open(image_path).convert("L")  # "L" = 8-bit grayscale
    arr = np.array(img, dtype=np.float32)
    return np.sum(arr) / 255.0 * u_max_step

if __name__ == "__main__":
    path = "/Users/mark/Documents/Code/SphericalTrace/testImages/testray1048.png"

    # Ask user for multiplier
    try:
        multiplier = float(input("Enter u_max_step: "))
    except ValueError:
        print("❌ Invalid number input.")
        exit(1)

    total = sum_image_values(path, multiplier)
    print(f"number of total steps: {total}")