#********************************************
#Identify Mico8 compiler toolchain binaries
#********************************************
CC=lm8-elf-gcc
LD=lm8-elf-ld
AS=lm8-elf-as
AR=lm8-elf-ar

#*********************************************
# Add to C-flags
#*********************************************
CFLAGS += $(foreach inc_path, $(INCLUDE_PATH), -I$(inc_path))

#*********************************************
# Add to linker Flags
#*********************************************
LDFLAGS +=

#*******************************************************************************
# Enhance dependencies to depend on all the makefiles as well as source-files
# as well as object-files
#*******************************************************************************
OBJS=$(sort $(C_SRCS:.c=.o)			\
			$(patsubst %.C, %.o,$(CXX_SRCS))	\
			$(patsubst %.S, %.o, $(patsubst %.s, %.o, $(ASM_SRCS))))

ARCHIVE_OBJS=$(addprefix $(OUTPUT_DIR)/, $(OBJS))

###############################################################################
# BUILD-RULES 
# TODO: ADD CPP RULES AND OTHER RULES...
###############################################################################
# Enhance dependency to include makefiles as well as source-file
$(OUTPUT_DIR)/%.o : %.c
	$(CC) -c $(CPU_CONFIG) $(CFLAGS) $< -o $@
	echo -n $(dir $@) > $(@:%.o=%.d) && \
	$(CC) $(CPU_CONFIG) $(CFLAGS) -MM -MG $< >> $(@:%.o=%.d)

$(OUTPUT_DIR)/%.o : %.C
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $< -o $@
	echo -n $(dir $@) > $(@:%.o=%.d) && \
	$(CC) $(CPU_CONFIG) $(CFLAGS)  -MM -MG $< >> $(@:%.o=%.d)

$(OUTPUT_DIR)/%.o: %.s
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $(ASMFLAGS) $< -o $@

$(OUTPUT_DIR)/%.o: %.S
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $(ASMFLAGS) $< -o $@

%.o: %.c
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $< -o $(OUTPUT_DIR)/$@

%.o: %.C
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $< -o $(OUTPUT_DIR)/$@

%.o: %.S
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $(ASMFLAGS) $< -o $(OUTPUT_DIR)/$@

%.o: %.s
	$(CC) -c $(CPU_CONFIG) $(CFLAGS)  $(ASMFLAGS) $< -o $(OUTPUT_DIR)/$@

# Enhance dependency to include other stuff
$(OUTPUT_DIR)/%.elf : $(PROJECT_LIBRARY) $(ARCHIVE_OBJS)
	$(CC) $(CPU_CONFIG) $(LDFLAGS) $(PROJECT_LINKER_SCRIPT) -o $@ $(ARCHIVE_OBJS) $(PROJECT_LIBRARY)

