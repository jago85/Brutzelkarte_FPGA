# Brutzelkarte_FPGA
The Brutzelkarte FPGA description code in VHDL

The code may need some cleanup. It is the result of multiple iterations from the first prototype to the current version. It may not be perfect but works. There are still some unimplemented features.

Feel free to leave me a message if you find bugs or have suggestions for improvements.

# Cart Interface (CI) reference
## Base Address
Address: 0x18000000

## Cart Control Register
Offset: 0x00000000  
Effective Address: 0x18000000  
Access: Read /Write  

Description:  
Controls the emulation features of the cart.

| 31 - 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--|--|--|--|--|--|--|--|
| Reserved | UART EN | Mapping EN | FlashRAM EN | SRAM EN | EEP SEL | EEP EN | FLASH SEL |

FLASH SEL: '0' Boot / '1' ROM  
EEP EN: '1' EEPROM emulation enabled  
EEP SEL: EEPROM Type select ('0' = 4 KBit / '1' 16 KBit, only valid if EEP EN = '1')  
SRAM EN: '1' enables SRAM emulation (supports 32KiB and 3x32KiB SRAM)  
FlashRAM EN: '1' enables FlashRAM emulation  
Mapping EN: '1' enables ROM FLASH mapping  
UART EN: '1' enables the UART port (this disables the other cart control funtions)

*Hint:  
SRAM EN and FlashRAM EN may not be '1' at the same time. Otherwise the result is undefined.*

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

## UART Status Register
Offset: 0x00000014 
Effective Address: 0x18000014  
Access: Read / Write '1' to reset

Description:  
Status of the TX / RX FIFOs and the transmitter.

| 31 - 12 | 11 | 10 | 9 | 8 | 7 - 4 | 3 | 2 | 1 | 0 |
|--|--|--|--|--|--|--|--|--|--|
| Reserved | RXOF | RXHF | RXF | RXNE | Reserved | TXACT| TXHF | TXF | TXNF |

TXACT: TX active  
TXHF: TX FIFO Half Full  
TXF: TX FIFO Full  
TXNF: TX FIFO Not Full (can send at least one character)

RXOF: RX FIFO Overflow (Writing '1' resets the flag)  
RXHF: RX FIFO Half Full  
RXF: RX FIFO Full  
RXNE: RX FIFO Not Empty (can receive at least one character)

## UART TX Free Count Register
Offset: 0x00000018  
Effective Address: 0x18000018  
Access: Read Only  

Description:  
Number of free characters in the TX FIFO.

| 31 - 11  | 10 - 0 |
|--|--|
| Reserved | Tx free count |

## UART RX Ready Count Register
Offset: 0x0000001C  
Effective Address: 0x1800001C  
Access: Read Only

Description:  
Number of characters in the RX FIFO.

| 31 - 11  | 10 - 0 |
|--|--|
| Reserved | Rx ready count |

## UART TXD Register
Offset: 0x00000110  
Effective Address: 0x18000020  
Access: Write Only  

Description:  
Writes one character to the TX FIFO.

## UART RXD Register
Offset: 0x00000120  
Effective Address: 0x18000028  
Access: Read Only

Description:  
Reads one character from the RX FIFO.

## UART TX DMA Space
Offset: 0x00001000  
Size: 1K  
Effective Addresses: 0x18001000 - 0x180013FF  
Access: Write Only

Description:  
Every write to this address space writes to the TX FIFO. In theory the cart supports 16 bit writes (2 characters). The machine supports only 64 bit aligned DMA accesses in 64 bit blocks.

## UART RX DMA Space
Offset: 0x00001400  
Size: 1K  
Effective Addresses: 0x18001400 - 0x180017FF  
Access: Read Only

Description:  
Every read from this address space reads from the RX FIFO. In theory the cart supports 16 bit reads (2 characters). The machine supports only 64 bit aligned DMA accesses in 64 bit blocks.

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
