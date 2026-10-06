"""Split the legacy statistics strip and remove its exterior baked shadow.
Usage: python3 tools/build_statistics_icons.py --source ORIGINAL_STRIP.png
The original input is available at git revision 6100866, path:
assets/flash_ui/components/part_ad6b91577988ccaf5ef3.png
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes

ROOT = Path(__file__).resolve().parents[1]
CROPS = {'stat_skull':(0,0,28,38), 'stat_tick':(172,2,202,38)}

def remove_exterior_shadow(image):
    rgba = np.asarray(image.convert('RGBA')).copy()
    brightness = rgba[:,:,:3].mean(axis=2) / 255.0
    alpha = rgba[:,:,3].astype(float) / 255.0
    # Bright silhouette encloses the face details. Dark internal eyes/teeth
    # survive, while dark pixels connected to the exterior are the old shadow.
    interior = binary_fill_holes((brightness >= 0.62) & (alpha >= 0.12))
    coverage = np.clip((brightness - 0.12) / (0.62 - 0.12), 0.0, 1.0)
    rgba[:,:,3] = np.rint(alpha * np.where(interior,1.0,coverage) * 255).astype('uint8')
    # Edge coverage now carries antialiasing; do not keep shadow-gray edge RGB.
    edge = (~interior) & (rgba[:,:,3] > 0)
    rgba[:,:,:3][edge] = 225
    rgba[:,:,:3][rgba[:,:,3] == 0] = 0
    return Image.fromarray(rgba)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'assets/flash_ui/components')
    args=parser.parse_args()
    source=Image.open(args.source).convert('RGBA')
    assert source.size == (202,38)
    args.output.mkdir(parents=True,exist_ok=True)
    for name,bounds in CROPS.items():
        clean=remove_exterior_shadow(source.crop(bounds))
        clean.save(args.output/(name+'.png'),optimize=True)
        print(name,clean.size)
if __name__=='__main__':main()
