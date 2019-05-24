#ifndef _ASM_X86_AKAROS_H
#define _ASM_X86_AKAROS_H

#ifdef CONFIG_AKAROS_GUEST

#define AKAROS_VMCALL_PRINTC           0x1
#define AKAROS_VMCALL_SMPBOOT          0x2
#define AKAROS_VMCALL_GET_TSCFREQ      0x3
#define AKAROS_VMCALL_TRACE_TF         0x4
#define AKAROS_VMCALL_SHUTDOWN         0x5

extern struct console akaros_boot_console;

#endif /* CONFIG_AKAROS_GUEST */

#endif /* _ASM_X86_AKAROS_H */
