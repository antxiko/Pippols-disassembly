import sys
rom=open('pippols.rom','rb').read(); org=0x4000
def words(a,n):
    o=a-org
    return [rom[o+2*i]|(rom[o+2*i+1]<<8) for i in range(n)]
for call in sys.argv[1:]:
    c=int(call,16); t=c+3
    n=1; 
    while True:
        w=words(t,n)
        lim=min(x for x in w if x)
        if t+2*n>=lim: break
        n+=1
    w=words(t,n)
    print('call 0x%04X -> tabla 0x%04X, %d palabras (0x%04X-0x%04X)'%(c,t,n,t,t+2*n-1))
    for i,v in enumerate(w): print('   %2d 0x%04X'%(i,v))
