ENTRY(_start_hal)
PROVIDE(_start_trap = _start_trap_hal);

PROVIDE(_stack_start = ORIGIN(REGION_STACK) + LENGTH(REGION_STACK));
PROVIDE(_max_hart_id = 0);
PROVIDE(_hart_stack_size = 2K);
PROVIDE(_heap_size = 0);

PROVIDE(UserSoft = DefaultHandler);
PROVIDE(SupervisorSoft = DefaultHandler);
PROVIDE(MachineSoft = DefaultHandler);
PROVIDE(UserTimer = DefaultHandler);
PROVIDE(SupervisorTimer = DefaultHandler);
PROVIDE(MachineTimer = DefaultHandler);
PROVIDE(UserExternal = DefaultHandler);
PROVIDE(SupervisorExternal = DefaultHandler);
PROVIDE(MachineExternal = DefaultHandler);

PROVIDE(DefaultHandler = DefaultInterruptHandler);
PROVIDE(ExceptionHandler = DefaultExceptionHandler);

/* # Pre-initialization function */
/* If the user overrides this using the `#[pre_init]` attribute or by creating a `__pre_init` function,
   then the function this points to will be called before the RAM is initialized. */
PROVIDE(__pre_init = default_pre_init);

/* A PAC/HAL defined routine that should initialize custom interrupt controller if needed. */
PROVIDE(_setup_interrupts = default_setup_interrupts);

/* # Multi-processing hook function
   fn _mp_hook() -> bool;

   This function is called from all the harts and must return true only for one hart,
   which will perform memory initialization. For other harts it must return false
   and implement wake-up in platform-dependent way (e.g. after waiting for a user interrupt).
*/
PROVIDE(_mp_hook = default_mp_hook);

SECTIONS
{
  .rodata :
  {
    _srodata = .;
    *(EXCLUDE_FILE (*libriscv-*.rlib:riscv.*) .rodata);
    *(EXCLUDE_FILE (*libriscv-*.rlib:riscv.*) .rodata.*);
    *(EXCLUDE_FILE (*libriscv_rt-*.rlib:riscv-rt.*) .rodata);
    *(EXCLUDE_FILE (*libriscv_rt-*.rlib:riscv-rt.*) .rodata.*);
    *(.srodata .srodata.*);
    *(.rodata .rodata.*);

    /* 4-byte align the end (VMA) of this section.
       This is required by LLD to ensure the LMA of the following .data
       section will have the correct alignment. */
    . = ALIGN(4);
    _erodata = .;
  } > REGION_RODATA AT>ROM

  .rwtext :
  {
    _srwtext = .;
    /* Put reset handler first in .rwtext section so it ends up as the entry */
    /* point of the program. */
    KEEP(*(.init));
    KEEP(*(.init.rust));
    . = ALIGN(4);
    KEEP(*(.trap));
    KEEP(*(.trap.rust));

    *libriscv-*.rlib:riscv.*(.literal .text .literal.* .text.*);
    *libriscv_rt-*.rlib:riscv-rt.*(.literal .text .literal.* .text.*);
    *(.rwtext);
    . = ALIGN(4);
    _erwtext = .;
  } > REGION_RWTEXT AT>ROM

  .rwtext.dummy (NOLOAD):
  {
    /* This section is required to skip .rwtext area because REGION_RWTEXT
     * and REGION_BSS reflect the same address space on different buses.
     */

    . = ORIGIN(REGION_BSS) + _erwtext - _srwtext;
  } > REGION_BSS

  .bss (NOLOAD) :
  {
    _sbss = .;
    *(.sbss .sbss.* .bss .bss.*);
    . = ALIGN(4);
    _ebss = .;
  } > REGION_BSS

  .uninit (NOLOAD) : ALIGN(4)
  {
    . = ALIGN(4);
    __suninit = .;
    *(.uninit .uninit.*);
    . = ALIGN(4);
    __euninit = .;
  } > REGION_BSS

  /* fictitious region that represents the memory available for the heap */
  .heap (NOLOAD) :
  {
    _sheap = .;
    . += _heap_size;
    . = ALIGN(4);
    _eheap = .;
  } > REGION_HEAP

  /* fictitious region that represents the memory available for the stack */
  .stack (NOLOAD) :
  {
    _estack = .;
    . = ABSOLUTE(_stack_start);
    _sstack = .;
  } > REGION_STACK

  .data :
  {
    _sdata = .;
    /* Must be called __global_pointer$ for linker relaxations to work. */
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.sdata .sdata.* .sdata2 .sdata2.*);
    *(.data .data.*);
    *libriscv-*.rlib:riscv.*(.rodata .rodata.*);
    *libriscv_rt-*.rlib:riscv-rt.*(.rodata .rodata.*);
    . = ALIGN(4);
    _edata = .;
  } > REGION_DATA AT>ROM

  .rtc_fast.text :
  {
    _srtc_fast_text = .;
    *(.rtc_fast.literal .rtc_fast.text .rtc_fast.literal.* .rtc_fast.text.*)
    . = ALIGN(4);
    _ertc_fast_text = .;
  } > REGION_RTC_FAST AT>ROM

  .rtc_fast.data :
  {
    _rtc_fast_data_start = ABSOLUTE(.);
    *(.rtc_fast.data .rtc_fast.data.*)
    . = ALIGN(4);
    _rtc_fast_data_end = ABSOLUTE(.);
  } > REGION_RTC_FAST AT>ROM

 .rtc_fast.bss (NOLOAD) : ALIGN(4)
  {
    _rtc_fast_bss_start = ABSOLUTE(.);
    *(.rtc_fast.bss .rtc_fast.bss.*)
    . = ALIGN(4);
    _rtc_fast_bss_end = ABSOLUTE(.);
  } > REGION_RTC_FAST

 .rtc_fast.noinit (NOLOAD) : ALIGN(4)
  {
    *(.rtc_fast.noinit .rtc_fast.noinit.*)
  } > REGION_RTC_FAST

  /* The alignment of the "text" output section is forced to
   * 0x00010000 (64KB) to ensure that it will be allocated at the beginning
   * of the next available Flash block.
   * This is required to meet the following constraint from the external
   * flash MMU:
   *    VMA % 64KB == LMA % 64KB
   * i.e. the lower 16 bits of both the virtual address (address seen by the
   * CPU) and the load address (physical address of the external flash) must
   * be equal.
   */

  .text.dummy (NOLOAD) : ALIGN(0x10000)
  {
    /* This section is required to skip .rodata area because REGION_TEXT
     * and REGION_RODATA reflect the same address space on different buses.
     */

    . += SIZEOF(.rodata);
  } > REGION_TEXT

  .text : ALIGN(0x10000)
  {
    _stext = .;
    *(EXCLUDE_FILE (*libriscv-*.rlib:riscv.*) .text)
    *(EXCLUDE_FILE (*libriscv-*.rlib:riscv.*) .text.*)
    *(EXCLUDE_FILE (*libriscv_rt-*.rlib:riscv-rt.*) .text)
    *(EXCLUDE_FILE (*libriscv_rt-*.rlib:riscv-rt.*) .text.*)
    *(.text .text.*);
    _etext = .;
  } > REGION_TEXT AT>ROM

  /* fake output .got section */
  /* Dynamic relocations are unsupported. This section is only used to detect
     relocatable code in the input files and raise an error if relocatable code
     is found */
  .got (INFO) :
  {
    KEEP(*(.got .got.*));
  }

  .eh_frame (INFO) : { KEEP(*(.eh_frame)) }
  .eh_frame_hdr (INFO) : { *(.eh_frame_hdr) }
}

PROVIDE(_sidata = _erodata + 8);
PROVIDE(_irwtext = ORIGIN(DROM) + _text_size + _rodata_size + _data_size);
PROVIDE(_irtc_fast_text = ORIGIN(DROM) + _text_size + _rodata_size + _data_size + _rwtext_size);
PROVIDE(_irtc_fast_data = ORIGIN(DROM) + _text_size + _rodata_size + _data_size + _rwtext_size + _fast_text_size);

/* Do not exceed this mark in the error messages above                                    | */
ASSERT(ORIGIN(REGION_TEXT) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_TEXT must be 4-byte aligned");

ASSERT(ORIGIN(REGION_RODATA) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_RODATA must be 4-byte aligned");

ASSERT(ORIGIN(REGION_DATA) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_DATA must be 4-byte aligned");

ASSERT(ORIGIN(REGION_HEAP) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_HEAP must be 4-byte aligned");

ASSERT(ORIGIN(REGION_TEXT) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_TEXT must be 4-byte aligned");

ASSERT(ORIGIN(REGION_STACK) % 4 == 0, "
ERROR(riscv-rt): the start of the REGION_STACK must be 4-byte aligned");

ASSERT(_stext % 4 == 0, "
ERROR(riscv-rt): `_stext` must be 4-byte aligned");

ASSERT(_sdata % 4 == 0 && _edata % 4 == 0, "
BUG(riscv-rt): .data is not 4-byte aligned");

ASSERT(_sidata % 4 == 0, "
BUG(riscv-rt): the LMA of .data is not 4-byte aligned");

ASSERT(_sbss % 4 == 0 && _ebss % 4 == 0, "
BUG(riscv-rt): .bss is not 4-byte aligned");

ASSERT(_sheap % 4 == 0, "
BUG(riscv-rt): start of .heap is not 4-byte aligned");

ASSERT(_stext + SIZEOF(.text) < ORIGIN(REGION_TEXT) + LENGTH(REGION_TEXT), "
ERROR(riscv-rt): The .text section must be placed inside the REGION_TEXT region.
Set _stext to an address smaller than 'ORIGIN(REGION_TEXT) + LENGTH(REGION_TEXT)'");

ASSERT(SIZEOF(.stack) > (_max_hart_id + 1) * _hart_stack_size, "
ERROR(riscv-rt): .stack section is too small for allocating stacks for all the harts.
Consider changing `_max_hart_id` or `_hart_stack_size`.");

ASSERT(SIZEOF(.got) == 0, "
.got section detected in the input files. Dynamic relocations are not
supported. If you are linking to C code compiled using the `gcc` crate
then modify your build script to compile the C code _without_ the
-fPIC flag. See the documentation of the `gcc::Config.fpic` method for
details.");

/* Do not exceed this mark in the error messages above                                    | */