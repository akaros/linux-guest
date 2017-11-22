/*
 * Akaros paravirt_ops implementation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * Copyright (C) 2017, Google Inc.
 *   Authors: Gan Shun Lim <ganshun@gmail.com>
 */

#include <linux/cpu.h>
#include <linux/cpuidle.h>
#include <asm/hypervisor.h>
#include <asm/mwait.h>

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

	return;
}

bool akaros_para_available(void)
{
	init_akaros_cpuid_base();
	return akaros_cpuid_base != 0;
}
EXPORT_SYMBOL_GPL(akaros_para_available);

/* Determines if akaros is the top level hypervisor. */
static bool akaros_top;

bool akaros_para_top(void)
{
	return akaros_top;
}
EXPORT_SYMBOL_GPL(akaros_para_top);

static unsigned long akaros_get_tsc_khz(void)
{
	/* TODO: Aquired via commandline.  Can replace with a VMCALL, and maybe
	 * remove the lapic_timer_frequency hack too. */
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

static void __init akaros_init_platform(void)
{
	akaros_top = true;

	x86_platform.calibrate_tsc = akaros_get_tsc_khz;
	x86_platform.calibrate_cpu = akaros_get_tsc_khz;

	/* Akaros's LAPIC timer emulation is hardcoded for a 1 MHz timer. */
	lapic_timer_frequency = 1000000 / HZ;

	pv_irq_ops.safe_halt = akaros_safe_halt;
	pv_irq_ops.halt = akaros_halt;
}

static uint32_t __init akaros_detect(void)
{
	init_akaros_cpuid_base();
	return akaros_cpuid_base;
}

const struct hypervisor_x86 x86_hyper_akaros __refconst = {
	.name			= "AKAROS",
	.detect			= akaros_detect,
	.x2apic_available	= akaros_para_available,
	.init_platform	= akaros_init_platform,
};
EXPORT_SYMBOL_GPL(x86_hyper_akaros);
