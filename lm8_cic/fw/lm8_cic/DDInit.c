#include "DDStructs.h"

void LatticeDDInit(void)
{

    /* initialize io instance of gpio */
    MicoGPIOInit(&gpio_io);
    
    /* invoke application's main routine*/
    main();
}

