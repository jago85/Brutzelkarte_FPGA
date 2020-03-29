#ifndef __SYSTEM_CONFIG_H_
#define __SYSTEM_CONFIG_H_


#define FPGA_DEVICE_FAMILY    "MachXO2"
#define PLATFORM_NAME         "lm8_cic"
#define USE_PLL               (0)
#define CPU_FREQUENCY         (25000000)


/* FOUND 1 CPU UNIT(S) */

/*
 * CPU Instance LM8 component configuration
 */
#define CPU_NAME "LM8"

/*
 * io component configuration
 */
#define IO_NAME  "io"
#define IO_BASE_ADDRESS  (0x80000000)
#define IO_SIZE  (16)
#define IO_CHARIO_IN        (0)
#define IO_CHARIO_OUT       (0)
#define IO_WB_DAT_WIDTH  (8)
#define IO_WB_ADR_WIDTH  (4)
#define IO_ADDRESS_LOCK  (1)
#define IO_DISABLE  (0)
#define IO_OUTPUT_PORTS_ONLY  (0)
#define IO_INPUT_PORTS_ONLY  (0)
#define IO_TRISTATE_PORTS  (0)
#define IO_BOTH_INPUT_AND_OUTPUT  (1)
#define IO_DATA_WIDTH  (1)
#define IO_INPUT_WIDTH  (3)
#define IO_OUTPUT_WIDTH  (1)
#define IO_IRQ_MODE  (0)
#define IO_LEVEL  (0)
#define IO_EDGE  (0)
#define IO_EITHER_EDGE_IRQ  (0)
#define IO_POSE_EDGE_IRQ  (0)
#define IO_NEGE_EDGE_IRQ  (0)


#endif /* __SYSTEM_CONFIG_H_ */
