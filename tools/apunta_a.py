import sys
rom=open('pippols.rom','rb').read(); org=0x4000
for arg in sys.argv[1:]:
    a=int(arg,16)
    lo=a&0xFF; hi=a>>8
    hits=[]
    for i in range(len(rom)-1):
        if rom[i]==lo and rom[i+1]==hi:
            pre=rom[i-1] if i else 0
            tag={0xCD:'call',0xC3:'jp',0x21:'ld hl',0x11:'ld de',0x01:'ld bc',0x22:'ld (),hl',0x2A:'ld hl,()',0x32:'ld (),a',0x3A:'ld a,()'}.get(pre,'palabra')
            hits.append('0x%04X[%s]'%(org+i,tag))
    print('0x%04X: %s'%(a,' '.join(hits) if hits else 'NADIE'))
