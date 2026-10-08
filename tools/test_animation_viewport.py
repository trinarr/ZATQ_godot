import tempfile
import unittest
from pathlib import Path
from PIL import Image
from animation_viewport import animation_viewport,STAGE

class AnimationViewportTest(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
 def tearDown(self):self.temp.cleanup()
 def photo(self,size):
  Image.new('RGB',size).save(self.root/'photo.png')
  return {'photo':'photo.png','matrix':(1,0,0,1,0,0),'color':(1,1,1,1,0,0,0)}
 def viewport(self,ref,poses):return animation_viewport(ref,poses,self.root,self.root)
 def test_dorvud_panorama(self):
  ref=self.photo((1415,480));end=dict(ref,matrix=(1,0,0,1,-615,0))
  self.assertEqual(self.viewport(ref,[ref,end]),(0,0,1415,480))
 def test_static_wide_photo_does_not_allocate_invisible_pixels(self):
  ref=self.photo((1415,480));self.assertEqual(self.viewport(ref,[ref]),STAGE)
 def test_vertical_panorama(self):
  ref=self.photo((800,600));end=dict(ref,matrix=(1,0,0,1,0,-120))
  self.assertEqual(self.viewport(ref,[ref,end]),(0,0,800,600))
 def test_zoom_out_reveals_overscan(self):
  ref=self.photo((1000,600));end=dict(ref,matrix=(.8,0,0,.8,0,0))
  self.assertEqual(self.viewport(ref,[ref,end]),(0,0,1000,600))
 def test_reference_offset_is_kept(self):
  ref=self.photo((1000,480));ref['matrix']=(1,0,0,1,-50,0)
  end=dict(ref,matrix=(1,0,0,1,-200,0))
  self.assertEqual(self.viewport(ref,[ref,end]),(0,0,950,480))
 def test_hidden_poses_do_not_require_pixels(self):
  ref=self.photo((1415,480));end=dict(ref,matrix=(1,0,0,1,-615,0),color=(1,1,1,0,0,0,0))
  self.assertEqual(self.viewport(ref,[ref,end]),STAGE)
 def test_singular_pose_is_safe(self):
  ref=self.photo((1415,480));end=dict(ref,matrix=(0,0,0,0,0,0))
  self.assertEqual(self.viewport(ref,[ref,end]),STAGE)

if __name__=='__main__':unittest.main()
