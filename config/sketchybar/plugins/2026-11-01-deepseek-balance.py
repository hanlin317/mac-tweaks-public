#!/usr/bin/env python3
"""Fetch only DeepSeek's read-only balance endpoint. Key remains in Keychain."""
import datetime as dt,fcntl,json,os,subprocess as sp,time,urllib.request
from decimal import Decimal
from pathlib import Path
c=Path.home()/'.cache/sketchybar';c.mkdir(exist_ok=True)
f=c/'2026-11-01-deepseek-balance.json'
try:data=json.loads(f.read_text())
except (OSError,ValueError):data={}
lock=(c/'2026-11-01-deepseek-balance.lock').open('w')
try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);locked=True
except BlockingIOError:locked=False
if locked and time.time()-data.get('attempted_at',0)>=300:
 data['attempted_at']=time.time()
 try:
  key=sp.run(['/usr/bin/security','find-generic-password','-a',os.environ.get('USER',''),'-s','local.sketchybar.deepseek','-w'],capture_output=True,text=True,timeout=8,check=True).stdout.strip()
  class NoRedirect(urllib.request.HTTPRedirectHandler):
   def redirect_request(self,*args,**kwargs):return None
  req=urllib.request.Request('https://api.deepseek.com/user/balance',headers={'Authorization':'Bearer '+key,'Accept':'application/json'})
  with urllib.request.build_opener(NoRedirect).open(req,timeout=12) as r:raw=json.load(r)
  entries=[]
  for b in raw.get('balance_infos',[]):
   if b.get('currency') not in ('USD','CNY'):continue
   entry={'currency':b['currency']}
   for field in ('total_balance','granted_balance','topped_up_balance'):
    value=Decimal(str(b[field]));assert value.is_finite();entry[field]=str(value)
   entries.append(entry)
  assert entries
  data.update(balances=entries,available=bool(raw.get('is_available')),checked_at=time.time(),error=False)
 except Exception:data['error']=True
 tmp=f.with_suffix('.tmp');tmp.write_text(json.dumps(data));tmp.chmod(0o600);tmp.replace(f)
entries=data.get('balances',[])
shown=[b for b in entries if Decimal(b['total_balance']) != 0] or entries[:1]
label=' / '.join(b['currency']+' '+format(Decimal(b['total_balance']),'.2f') for b in shown) or '—'
if data.get('error') and entries:label+=' *'
rows=[]
for b in entries:
 for title,field in [('left','total_balance'),('top-up','topped_up_balance'),('grant','granted_balance')]:rows.append([title,b['currency']+' '+format(Decimal(b[field]),'.2f')])
checked=data.get('checked_at')
rows.append(['updated',dt.datetime.fromtimestamp(checked).astimezone().strftime('%a %H:%M') if checked else 'not yet available'])
if data.get('error'):rows.append(['status','refresh unavailable; showing last known balance' if entries else 'balance unavailable'])
else:rows.append(['status','available' if data.get('available') else 'insufficient balance'])
print(json.dumps({'label':label,'rows':rows,'error':bool(data.get('error'))}))
