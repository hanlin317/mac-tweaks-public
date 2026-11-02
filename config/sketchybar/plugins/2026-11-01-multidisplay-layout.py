#!/usr/bin/env python3
"""Keep media beside the left island and size it safely for every screen."""
import fcntl,json,os,subprocess as sp,sys,time
from pathlib import Path
root=Path(os.environ['CONFIG_DIR']);cache=Path.home()/'.cache/sketchybar'
def query(name):
 for attempt in range(8):
  r=sp.run(['sketchybar','--query',name],capture_output=True,text=True)
  try:
   if r.returncode==0 and r.stdout.strip():return json.loads(r.stdout)
  except ValueError:pass
  time.sleep(.05*(attempt+1))
 raise ValueError(name)
def read(name,fallback):
 try:return (cache/name).read_text().strip()
 except OSError:return fallback
def width(text):return int(sp.check_output(['perl',str(root/'plugins/width.pl'),text],text=True))
def layout():
 lock=(cache/'layout.lock').open('w')
 try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 except BlockingIOError:return
 displays=query('displays');left=query('island.left')['bounding_rects'];media=query('island.media')['bounding_rects'];item=query('media')
 room=[];fixed=[]
 for d in displays:
  key=f"display-{d['arrangement-id']}"
  if key not in left or left[key]['origin'][0]==-9999:continue
  r=left[key];le=round(r['origin'][0]+r['size'][0]-d['frame']['x'])
  edges=sp.check_output([str(root/'helper/notch'),str(d['DirectDisplayID'])],text=True).split()
  room.append(int(edges[0])-5-le-5)
  if key in media and media[key]['origin'][0]!=-9999:fixed.append(round(media[key]['size'][0])-item['label']['width'])
 if not room or not fixed:return
 # Caption width also changes when the media app changes.
 aw=width(sys.argv[1]);extra=max(fixed)-item['icon']['width']+(aw+8)
 tw=max(20,min(room)-extra)
 text=sp.check_output(['perl',str(root/'plugins/fit.pl'),str(tw)],input='k\t'+sys.argv[2]+'\n',text=True).strip().split('\t',1)[-1]
 iw=extra+tw;iin=max(0,iw-4)
 ratio=max(0,min(1000,int(read('media_ratio','0'))));w=iin*ratio//1000;fw=iin
 if w>iin-22:fw=w;w=iin
 rw=max(0,iin-11-w);visible=ratio>0 and read('media_state','none')!='none'
 cmd=['sketchybar','--set','media',f'label={text}',f'icon.width={aw+8}',f'label.width={tw}']
 for name,pad,size in [('media.fill',2,fw),('media.fill.r',w+2,rw),('media.fill.c',w+2,iin-w)]:
  cmd+=['--set',name,'associated_display=0','drawing='+('on' if visible else 'off'),f'padding_left={pad}',f'label.width={size}',f'padding_right={-pad-size}']
 sp.run(cmd,check=True,stdout=sp.DEVNULL)
 (cache/'media_iw').write_text(str(iw))
try:layout()
except (ValueError,KeyError,sp.SubprocessError,OSError):pass
