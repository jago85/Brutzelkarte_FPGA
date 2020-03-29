#ifndef LATTICE_DDINIT_HEADER_FILE
#define LATTICE_DDINIT_HEADER_FILE
#include "stddef.h"
/* platform frequency in MHz */
#define MICO8_CPU_CLOCK_MHZ (25000000)

/*Device-driver structure for lm8*/
#define LatticeMico8Ctx_t_DEFINED (1)
typedef struct st_LatticeMico8Ctx_t {
    const char*   name;
} LatticeMico8Ctx_t;


/* lm8 instance LM8*/
extern struct st_LatticeMico8Ctx_t lm8_LM8;


/*Device-driver structure for gpio*/
#define MicoGPIOCtx_t_DEFINED (1)
typedef struct st_MicoGPIOCtx_t {
    const char*   name;
    size_t   base;
    unsigned char   intrLevel;
    unsigned int   output_only;
    unsigned char   input_only;
    unsigned char   in_and_out;
    unsigned char   tristate;
    unsigned char   data_width;
    unsigned char   input_width;
    unsigned char   output_width;
    unsigned char   intr_enable;
} MicoGPIOCtx_t;


/* gpio instance io*/
extern struct st_MicoGPIOCtx_t gpio_io;

/* declare io instance of gpio */
extern void MicoGPIOInit(struct st_MicoGPIOCtx_t*);

extern int main();

#endif
