// SPDX-License-Identifier: GPL-2.0
/*
 * Akaros paravirt_ops implementation
 *
 * Copyright (C) 2017-2019, Google Inc.
 *   Gan Shun Lim <ganshun@gmail.com>
 *   Barret Rhoden <brho@google.com>
 */

#include <linux/console.h>
#include <linux/cpu.h>
#include <linux/cpuidle.h>
#include <asm/hypervisor.h>
#include <asm/mwait.h>
#include <asm/i8259.h>
#include <asm/timer.h>
#include <asm/reboot.h>
#include <asm/akaros.h>

/* For debugging, in lieu of a common header, copy this around.  The VMM will
 * trace_printf the current trapframe, viewable with dmesg. */
static __always_inline void vmcall_trace_tf(void)
{
	asm volatile ("movq %%rax, %%r11;"
		      "movl %[vmcall_nr], %%eax;"
		      "vmcall;"
		      "movq %%r11, %%rax"
		      : : [vmcall_nr]"i"(AKAROS_VMCALL_TRACE_TF): "r11");
}

static int akaros_cpuid_base = -1;

static void init_akaros_cpuid_base(void)
{
	/* Check if we've run this init function already. */
	if (akaros_cpuid_base != -1)
		return;

	akaros_cpuid_base = 0;

	if (boot_cpu_data.cpuid_level < 0)
		return;	/* So we don't blow up on old processors */

	if (boot_cpu_has(X86_FEATURE_HYPERVISOR))
		akaros_cpuid_base = hypervisor_cpuid_base("AKAROSINSIDE", 0);
}

static bool akaros_para_available(void)
{
	init_akaros_cpuid_base();
	return akaros_cpuid_base != 0;
}

static void vmcall_write(struct console *con, const char *str, unsigned n)
{
	char c;

	if (!hypervisor_is_type(X86_HYPER_AKAROS))
		return;
	while ((c = *str++) != '\0' && n-- > 0) {
		asm volatile ("movl %[vmcall_nr], %%eax;"
			      "movzbq %1, %%rdi;"
			      "vmcall;"
			      :  : [vmcall_nr]"i"(AKAROS_VMCALL_PRINTC), "g"(c)
			      : "rax", "rdi");
	}
}

struct console akaros_boot_console = {
	.name =		"akaros",
	.write =	vmcall_write,
	.flags =	CON_PRINTBUFFER,
	.index =	-1,
};

static unsigned long akaros_get_tsc_khz(void)
{
	unsigned long tsc_khz;

	asm volatile ("movl %[vmcall_nr], %%eax; vmcall"
		      : "=a"(tsc_khz)
		      : [vmcall_nr]"i"(AKAROS_VMCALL_GET_TSCFREQ));

	return tsc_khz;
}

/* We need to monitor for mwait to work.  By picking memory that no one touches,
 * we won't inadvertently wake up.  I didn't notice a difference with using
 * current_thread_info()->flags.
 *
 * Note that the VMM told us (via cpuid) that monitor/mwait isn't supported, but
 * the instruction works on Akaros if it supports VMs. */
static struct untouched_memory {
} __aligned(L1_CACHE_BYTES) __aka_monitor_target;

static inline __cpuidle void akaros_safe_halt(void)
{
	__monitor(&__aka_monitor_target, 0, 0);
	__mwait(0x10, 1);	/* 1 -> break on interrupt */
}

static inline __cpuidle void akaros_halt(void)
{
	__monitor(&__aka_monitor_target, 0, 0);
	__mwait(0x10, 0);	/* 0 -> don't break on interrupt */
}

static int akaros_wake_smp(int apicid, unsigned long start_eip)
{
	/* Note we ignore start_eip and jump straight to secondary_startup_64,
	 * bypassing all of the real-mode shenanigans. */
	asm volatile ("movl %[vmcall_nr], %%eax;"
		      "movq $secondary_startup_64, %%rdi;"
		      "movq %1, %%rsi;"
		      "vmcall"
		       :
		       : [vmcall_nr]"i"(AKAROS_VMCALL_SMPBOOT),
		         "g"(initial_stack)
		       : "rax", "rdi", "rsi");

	return 0;
}

static void akaros_apic_post_init(void)
{
	apic->wakeup_secondary_cpu = akaros_wake_smp;
}

static void akaros_shutdown(void)
{
	asm volatile ("vmcall;" : : "a"(AKAROS_VMCALL_SHUTDOWN));
}

/*
 * Notes:
 * - We're still using legacy_pic.  virtio is doubling-up on those IRQs.  That
 *   needs work.  Xen PV was looking into faking the whole thing with their own
 *   PIC: https://lkml.org/lkml/2019/3/19/817.
 * - There are a lot of pv_ops and x86_platform ops we can use, such as
 *   get_wallclock() and cpu.io_delay().
 * - setup_force_cpu_cap(X86_FEATURE_TSC_KNOWN_FREQ)
 */
static void __init akaros_init_platform(void)
{
	x86_platform.calibrate_tsc = akaros_get_tsc_khz;
	x86_platform.calibrate_cpu = akaros_get_tsc_khz;
	x86_platform.apic_post_init = akaros_apic_post_init;

	x86_platform.legacy.warm_reset	= 0;
	x86_platform.legacy.rtc		= 0;
	x86_platform.legacy.i8042       = X86_LEGACY_I8042_PLATFORM_ABSENT;

	/* Akaros's LAPIC timer emulation is hardcoded for a 1 MHz timer. */
	lapic_timer_frequency = 1000000 / HZ;

	pv_ops.irq.safe_halt = akaros_safe_halt;
	pv_ops.irq.halt = akaros_halt;

	pv_info.name = "Akaros";

	machine_ops.power_off = akaros_shutdown;
	machine_ops.shutdown = akaros_shutdown;
	machine_ops.halt = akaros_shutdown;

#ifdef CONFIG_X86_IO_APIC
	no_timer_check = 1;
#endif
}

static uint32_t __init akaros_detect(void)
{
	init_akaros_cpuid_base();
	return akaros_cpuid_base;
}

const __initconst struct hypervisor_x86 x86_hyper_akaros = {
	.name			= "AKAROS",
	.detect			= akaros_detect,
	.type			= X86_HYPER_AKAROS,
	.init.x2apic_available	= akaros_para_available,
	.init.init_platform	= akaros_init_platform,
};
EXPORT_SYMBOL_GPL(x86_hyper_akaros);
