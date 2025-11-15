# Nexys Video PMOD Pin Mapping (VERIFIED)

## Source
Official Digilent master XDC:
https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Nexys-Video-Master.xdc

## PMOD JA (Verified Working ✅)
```
JA[0]: AB22  # JA1
JA[1]: AB21  # JA2
JA[2]: AB20  # JA3
JA[3]: AB18  # JA4
JA[4]: Y21   # JA7
JA[5]: AA21  # JA8
JA[6]: AA20  # JA9
JA[7]: AA18  # JA10
```

## PMOD JB (Verified Working ✅)
```
JB[0]: V9    # JB1
JB[1]: V8    # JB2
JB[2]: V7    # JB3
JB[3]: W7    # JB4
JB[4]: W9    # JB7
JB[5]: Y9    # JB8
JB[6]: Y7    # JB9
JB[7]: Y8    # JB10
```

## PMOD JC (Official Digilent - Now Verified ✅)
```
JC[0]: Y6    # JC1
JC[1]: AA6   # JC2
JC[2]: AA8   # JC3
JC[3]: AB8   # JC4
JC[4]: R6    # JC7
JC[5]: T6    # JC8
JC[6]: AB7   # JC9
JC[7]: AB6   # JC10
```

## Usage for 14-Segment Displays

### Configuration:
- **14 Segment Signals**: Use JA (8 pins) + JB top 6 pins (total 14 pins)
- **Digit Select (up to 8 digits)**: Use remaining JB (2 pins) + all JC (8 pins) = 10 pins available

### Mapping:
```
Segments (14 total):
  SEG[0-7]:   PMOD JA[0-7]   (A, B, C, D, E, F, G, H)
  SEG[8-13]:  PMOD JB[0-5]   (J, K, L, M, N, P)

Digit Select (4 digits for 2x LTP-3786E displays):
  DIG[0-3]:   PMOD JC[0-3]   (Y6, AA6, AA8, AB8)
```

## Notes
- All PMODs use LVCMOS33 IO standard
- Common-anode displays require active-LOW segments (invert in code)
- Digit select is active-HIGH
