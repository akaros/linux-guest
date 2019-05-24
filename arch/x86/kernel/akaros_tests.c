/* VMEXIT speed test, customized to go with Akaros's patch.  YMMV. */

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/time.h>
#include <asm/msr.h>
#include <asm/tsc.h>
#include <asm/hypervisor.h>

static int nr_loops = 100000;

static u64 tsc2nsec(u64 tsc)
{
	return tsc / (tsc_khz / 1000000);
}

static void run_vmexit_test(int type, char *msg)
{
	int i;
	u64 tsc_s, tsc_e;

	tsc_s = rdtsc_ordered();
	for (i = 0; i < nr_loops; i++)
		__asm__ __volatile__ ("vmcall" : : "D"(type));
	tsc_e = rdtsc_ordered();

	printk("Took %llu nsec (%llu ticks) per loop for test: %s\n",
	       tsc2nsec(tsc_e - tsc_s) / nr_loops,
	       (tsc_e - tsc_s) / nr_loops, msg);
}

static int __init vmexit_speed_init(void)
{
	if (!hypervisor_is_type(X86_HYPER_AKAROS)) {
		printk("Can only run as a VM on Akaros, aborting");
		return -1;
	}
	run_vmexit_test(0x1337, "ASM");
	run_vmexit_test(0x1338, "kernel");
	run_vmexit_test(0x1339, "kernel with unload");
	run_vmexit_test(0x1340, "userspace");
	return 0;
}

static void __exit vmexit_speed_exit(void)
{
}

module_init(vmexit_speed_init);
module_exit(vmexit_speed_exit);

module_param(nr_loops, int, 0644);
MODULE_PARM_DESC(nr_loops, "Number of loops per vmexit test");

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Barret Rhoden <brho@cs.berkeley.edu>");
MODULE_DESCRIPTION("VM exit speed test");
