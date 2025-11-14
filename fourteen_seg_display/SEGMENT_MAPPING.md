# LTP-3786E Actual Segment Mapping

## Your Display Layout

Based on your description, here's the actual segment layout:

```
           A
        ───────
      │ \  G  / │
    F │  \ | /  │ B
      │ P \|/ H │
        ─── ───
      │ M /|\ K │
    E │  / | \  │ C
      │ /  L  \ │
        ───────
           D
```

## Segment Names

| Position | Segment Name | Description |
|----------|--------------|-------------|
| Top horizontal | A | Single bar at top |
| Top right vertical | B | Right side top half |
| Bottom right vertical | C | Right side bottom half |
| Bottom horizontal | D | Single bar at bottom |
| Bottom left vertical | E | Left side bottom half |
| Top left vertical | F | Top side top half |
| Center top vertical | G | Center vertical, top half |
| Center bottom vertical | L | Center vertical, bottom half |
| Top right diagonal | H | Diagonal from center to top-right |
| Top left diagonal | P | Diagonal from center to top-left |
| Bottom right diagonal | K | Diagonal from center to bottom-right |
| Bottom left diagonal | M | Diagonal from center to bottom-left |

Note: Full 14-segment display with split middle horizontal (N and J)

## Bit Mapping (CONFIRMED)

From the FPGA's perspective (SEG(0 to 13)):

```
"ABCDEFGHJKLMNP" = "11110011110000"
 ^             ^
bit 0        bit 13

bit  0 = A (Top horizontal)
bit  1 = B (Top-right vertical)
bit  2 = C (Bottom-right vertical)
bit  3 = D (Bottom horizontal)
bit  4 = E (Bottom-left vertical)
bit  5 = F (Top-left vertical)
bit  6 = G (Center-top vertical)
bit  7 = H (Top-right diagonal)
bit  8 = J (Middle-right horizontal)
bit  9 = K (Bottom-right diagonal)
bit 10 = L (Center-bottom vertical)
bit 11 = M (Bottom-left diagonal)
bit 12 = N (Middle-left horizontal)
bit 13 = P (Top-left diagonal)
```

**Note:** The segment vector uses ascending indexing `(0 to 13)` for intuitive left-to-right reading where A=0, B=1, C=2, etc.

## Character Patterns

### Number '8' (all segments ON):
```
     A
   ─────
 F│P G H│B
  │ \|/ │
   ─────  (No middle horizontal!)
 E│M L K│C
  │ /|\ │
   ─────
     D
```

All segments: A B C D E F G L H P K M = 12 segments

### Number '0':
Segments: A B C D E F = outer rectangle

### Number '1':
Segments: B C = right side verticals

### Letter 'A':
Segments: A B C E F G L = looks like /\
                           │ │
                           │ │

## Standard to Your Mapping

| Standard Name | Your Name | Position |
|---------------|-----------|----------|
| A | A | Top horizontal |
| B | B | Top-right vertical |
| C | C | Bottom-right vertical |
| D | D | Bottom horizontal |
| E | E | Bottom-left vertical |
| F | F | Top-left vertical |
| G1 (left center) | G | Center-top vertical |
| G2 (right center) | L | Center-bottom vertical |
| H (bottom diagonal) | L | (duplicate? or different) |
| I (top vertical) | G | (same as G?) |
| J (top-right diag) | H | Top-right diagonal |
| K (bottom-right diag) | K | Bottom-right diagonal |
| P (top-left diag) | P | Top-left diagonal |
| M (bottom-left diag) | M | Bottom-left diagonal |

## Notes

Your display has:
- 6 outer segments (A, B, C, D, E, F) - the hexagon
- 2 center verticals (G top, L bottom)
- 2 middle horizontals (N left, J right)
- 4 diagonals (P, H, M, K)

Total: **14 segments** - full alphanumeric display!

## Complete Character Mapping

All characters are now mapped in `ascii_to_14seg.vhd` with the format `"ABCDEFGHJKLMNP"`:

### Numbers (0-9)
```
'0' = "11110111000000" = A B C D E F (outer rectangle)
'1' = "01100000000000" = B C (right side)
'2' = "11011000100010" = A B D E N J
'3' = "11110000100010" = A B C D N J
'4' = "01101000100010" = B C F N J
'5' = "10110100100010" = A C D F N J
'6' = "10111100100010" = A C D E F N J
'7' = "11100000000000" = A B C
'8' = "11111100100010" = A B C D E F N J (all outer + middle)
'9' = "11111000100010" = A B C D F N J
```

### Uppercase Letters (A-Z)
```
'A' = "11101100100010" = A B C E F N J
'B' = "11110000100111" = A B C D N J G L P
'C' = "10010111000000" = A D E F
'D' = "11110000100111" = A B C D N J G L P
'E' = "10011100100010" = A D E F N J
'F' = "10001100100010" = A E F N J
'G' = "10110111000010" = A C D E F J
'H' = "01101100100010" = B C E F N J
'I' = "10010000100111" = A D G L P
'J' = "01110110000000" = B C D E
'K' = "00001110010100" = E F H K
'L' = "00010111000000" = D E F
'M' = "01101110010001" = B C E F H P
'N' = "01101110000101" = B C E F K P
'O' = "11110111000000" = A B C D E F
'P' = "11001100100010" = A B E F N J
'Q' = "11110111000100" = A B C D E F K
'R' = "11001100100110" = A B E F N J K
'S' = "10110100100010" = A C D F N J
'T' = "10000000100111" = A G L P
'U' = "01110111000000" = B C D E F
'V' = "00000110000110" = E F M H
'W' = "01100110001010" = B C E F K M
'X' = "00000000010111" = H K M P (all diagonals)
'Y' = "00000000010101" = H K P
'Z' = "10010000000110" = A D H M
```

### Special Characters
```
' ' = "00000000000000" = (space - all off)
'-' = "00000000100010" = N J (minus)
'_' = "00010000000000" = D (underscore)
'=' = "00010000100010" = D N J (equals)
'+' = "00000000100111" = N J G L P (plus)
'*' = "00000000110111" = N J H K M P (asterisk - all center)
'/' = "00000000000110" = M H (forward slash)
'\' = "00000000000101" = K P (backslash)
'?' = "11000000100010" = A B N J (question mark)
'!' = "10000000100111" = A G L P (exclamation)
'.' = "00000000000000" = (period - uses DP if available)
```

## Visual Examples

### Number '8' (all segments):
```
     AAAAA
   FF   BB
   FF   BB
     NNJJ
   EE   CC
   EE   CC
     DDDDD
```

### Letter 'A':
```
     AAAAA
   FF   BB
   FF   BB
     NNJJ      (middle bars ON)
   EE   CC
   EE   CC
     
```

### Letter 'X' (diagonals only):
```
     
   \     /
    \   /
     \ /
     / \
    /   \
   /     \
     
```
