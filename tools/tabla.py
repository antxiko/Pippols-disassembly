import sys
rom=open('pippols.rom','rb').read()
org=0x4000
a=int(sys.argv[1],16); n=int(sys.argv[2])
off=a-org
w=[rom[off+2*i]|(rom[off+2*i+1]<<8) for i in range(n)]
for i,v in enumerate(w):
    print('%2d  0x%04X  ->  0x%04X'%(i,a+2*i,v))
print('min destino: 0x%04X'%min(x for x in w if x))
