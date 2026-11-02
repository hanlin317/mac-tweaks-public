#!/usr/bin/env python3
import fcntl,json,os,time,subprocess as sp
from pathlib import Path

def transition(s,action,now):
 s=dict(s);mode=s.get('mode','idle')
 if action in ('start25','start50'):
  duration=1500 if action=='start25' else 3000
  return {'mode':'running','end':now+duration,'remaining':duration,'duration':duration}
 if action=='pause' and mode=='running':s.update(mode='paused',remaining=max(0,int(s['end']-now)))
 if action=='resume' and mode=='paused':s.update(mode='running',end=now+s.get('remaining',0))
 if action=='reset':return {'mode':'idle'}
 if s.get('mode')=='running' and s['end']<=now:s.update(mode='done',remaining=0)
 return s

def render(s,now):
 mode=s.get('mode','idle')
 remaining=max(0,int(s.get('end',now)-now)) if mode=='running' else int(s.get('remaining',0))
 clock=f'{remaining//60:02d}:{remaining%60:02d}'
 return {'label':clock if mode=='running' else (clock+' paused' if mode=='paused' else ('Done' if mode=='done' else 'Focus')),'mode':mode,'remaining':remaining}

def main():
 import sys
 c=Path.home()/'.cache/sketchybar';c.mkdir(exist_ok=True);p=c/'2026-11-01-focus.json'
 with (c/'2026-11-01-focus.lock').open('w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  try:s=json.loads(p.read_text())
  except (OSError,ValueError):s={'mode':'idle'}
  old=s.copy();now=time.time();s=transition(s,sys.argv[1] if len(sys.argv)>1 else 'tick',now)
  if s!=old:
   tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(s));tmp.replace(p)
  if s.get('mode')=='done' and old.get('mode')=='running':
   sp.Popen(['/usr/bin/osascript','-e','display notification "Your focus session is complete." with title "Focus timer"'],stdout=sp.DEVNULL,stderr=sp.DEVNULL)
  print(json.dumps(render(s,now)))
if __name__=='__main__':main()
