# Brutzelkarte_FPGA
The Brutzelkarte FPGA description code in VHDL

The code may need some cleanup. It is the result of multiple iterations from the first prototype to the current version. It may not be perfect but works. There are still some unimplemented features.

Feel free to leave me a message if you find bugs or have suggestions for improvements.

# Cart Interface (CI)
## Base Address
Address: 0x18000000

## Control Register
Offset: 0x00000000  
Effective Address: 0x18000000  
Access: Read /Write  

Description:  
Controls the emulation features of the cart.

| 31 - 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--|--|--|--|--|--|--|
| Reserved | Mapping EN | FlashRAM EN | SRAM EN | EEP SEL | EEP EN | FLASH SEL |

FLASH SEL: '0' Boot / '1' ROM  
EEP EN: '1' EEPROM emulation enabled  
EEP SEL: EEPROM Type select ('0' = 4 KBit / '1' 16 KBit, only valid if EEP EN = '1')  
SRAM EN: '1' enables SRAM emulation (supports 32KiB and 3x32KiB SRAM)  
FlashRAM EN: '1' enables FlashRAM emulation  

*Hint:  
SRAM EN and FlashRAM EN may not be '1' at the same time. Otherwise the result will be undefined.*

## Version Register
Offset: 0x00000004  
Effective Address: 0x18000004  
Access: Read only  

Description:  
The version of the programable logic.

| 31 - 24 | 23 - 16 | 15 - 8 | 7 - 0 |
|--|--|--|--|
| 0x04 | Major | Minor | Debug |
## ~~ROM Offset Register~~
~~Offset: 0x00000008  
Effective Address: 0x18000008  
Access: Read /Write  
Description:  
Offset for read address in ROM FLASH~~  

**Replaced by ROM mapping.**

## Save Offset Register
Offset: 0x0000000C  
Effective Address: 0x1800000C  
Access: Read /Write  

Description:  
Offset of the save file in the SRAM in 1KiB blocks.

## Backup Register
Offset: 0x00000010  
Effective Address: 0x18000010  
Access: Read /Write  

Description:  
32 bit of user defined backup data. Can be used to remember the cart state during reset.

## ROM Mapping Register Set
Offset: 0x00000080  
Effective Address: 0x18000080  
Access: Read /Write  

Description:  
Set of 32 registers. Each registers maps 2 MiB of ROM address space to the ROM Flash. 512 MiB of FLASH can be addressed in 2 MiB blocks. This allows to split ROMs into parts of 2 MiB. If the cart memory is fragmented due to deletion of smaller ROMs, the free space can be used for bigger ROMs without having to completely rewriting the FLASH.  

Each register:
| 31 - 8 | 7 - 0|
|--|--|
| Reserved | Flash Mapping |

Register addresses and ROM addresses
| Address| Register | ROM address |
|--|--|--|
| 0x18000080 | Mapping Register 0 | 0x00000000 - 0x001FFFFF |
| 0x18000084 | Mapping Register 1 | 0x00200000 - 0x003FFFFF |
| ...| ... | ... |
| 0x18000098 | Mapping Register 30 | 0x03C00000 - 0x03DFFFFF |
| 0x1800009C | Mapping Register 31 | 0x03E00000 - 0x03FFFFFF |

Example usage:
 - Mapping is enabled in Cart Control Register
 - Console reads ROM address 0x00300208
 - Mapping register 1 is used (current value is 0x05)
 - Cart reads data from FLASH at address 0xA00208 (5 * 2 * 1024 * 1024 + 0x208)

*Hint:  
Mapping is only available for ROM FLASH. It is ignored for Boot FLASH.  
Mapping is ignored if disabled in Cart Control Register.*

## UART Control Register
Offset: 0x00001000  
Effective Address: 0x18001000  
Access: Read /Write  

Description:  
Controls the function of the UART.

| 31 - 1 | 0 |
|--|--|
| Reserved | UART EN |

UART EN: '1' enables the UART port (this disables the other cart control funtions)

## UART TX Status Register
Offset: 0x00001004  
Effective Address: 0x18001004  
Access: Read Only

Description:  
Status of the TX FIFO and the transmitter.

| 31 - 4 | 3 | 2 | 1 | 0 |
|--|--|--|--|--|
| Reserved | ACT| HF | F | NF |

ACT: TX active  
HF: TX FIFO Half Full  
F: TX FIFO Full  
NF: TX FIFO Not Full (can send at least one character)

## UART TX Free Count Register
Offset: 0x00001008  
Effective Address: 0x18001008  
Access: Read Only  

Description:  
Number of free characters in the TX FIFO.

| 31 - 11  | 10 - 0 |
|--|--|
| Reserved | Tx free count |

## UART RX Status Register
Offset: 0x0000100C  
Effective Address: 0x1800100C  
Access: Read / Write '1' to Reset  

Description:  
Status of the RX FIFO

| 31 - 4 | 3 | 2 | 1 | 0 |
|--|--|--|--|--|
| Reserved | OF | HF | F | NE |

OF: RX FIFO Overflow  
HF: RX FIFO Half Full  
F: RX FIFO Full  
NE: RX FIFO Not Empty (can receive at least one character)


## UART RX Ready Count Register
Offset: 0x00001010  
Effective Address: 0x18001010  
Access: Read Only

Description:  
Number of characters in the RX FIFO.

| 31 - 11  | 10 - 0 |
|--|--|
| Reserved | Rx ready count |

## UART TXD Register
Offset: 0x00001020  
Effective Address: 0x18001020  
Access: Write Only  

Description:  
Writes one character to the TX FIFO.

## UART RXD Register
Offset: 0x00001040  
Effective Address: 0x18001040  
Access: Read Only

Description:  
Reads one character from the RX FIFO.

## UART TX DMA Space
Offset: 0x00001400  
Size: 1K  
Effective Addresses: 0x18001400 - 0x180017FF  
Access: Write Only

Description:  
Every write to this address space writes to the TX FIFO. In theory the cart supports 16 bit writes (2 characters). The machine supports only 64 bit aligned DMA accesses in 64 bit blocks.

## UART RX DMA Space
Offset: 0x00001800  
Size: 1K  
Effective Addresses: 0x18001800 - 0x18001BFF  
Access: Read Only

Description:  
Every read from this address space reads from the RX FIFO. In theory the cart supports 16 bit reads (2 characters). The machine supports only 64 bit aligned DMA accesses in 64 bit blocks.

