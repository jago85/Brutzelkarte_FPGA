#-------------------------------------------------------
# Identify source-paths for this device's driver-sources
# that are built as part of the library-build (and not
# the application
#-------------------------------------------------------
LIBRARY_C_SRCS   += MicoInterrupts.c

LIBRARY_ASM_SRCS += MicoSleepHelper.S		

LIBRARY_CXX_SRCS +=

#-------------------------------------------------------
# Identify paths and resources for the top-level
# application (and not the library)
#-------------------------------------------------------
APP_ASM_SRCS     += crt0.S

