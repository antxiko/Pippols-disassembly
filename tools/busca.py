import sys
rom=open('pippols.rom','rb').read()
pat=bytes.fromhex(sys.argv[1].replace(' ',''))
org=0x4000
i=0
res=[]
while True:
    j=rom.find(pat,i)
    if j<0: break
    res.append(org+j); i=j+1
print(' '.join('0x%04X'%a for a in res), '   (%d)'%len(res))
