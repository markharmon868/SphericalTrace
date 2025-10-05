from PIL import Image
import numpy as np

def l2_distance(image1_path, image2_path):
    # Load both images
    img1 = Image.open(image1_path).convert("RGB")
    img2 = Image.open(image2_path).convert("RGB")

    # Check same resolution
    if img1.size != img2.size:
        raise ValueError("❌ Images must have the same resolution")

    # Convert to NumPy arrays
    arr1 = np.array(img1, dtype=np.float32)
    arr2 = np.array(img2, dtype=np.float32)

    # Compute L2 distance (Euclidean norm of pixel differences)
    diff = arr1 - arr2
    l2 = np.linalg.norm(diff)

    return l2

if __name__ == "__main__":
    path1 = "../images/references/reference_1.png"
    path2 = "../images/results/TeamA_1.png"

    distance = l2_distance(path1, path2)
    print(f"\nL2 distance between images:\n{distance}")