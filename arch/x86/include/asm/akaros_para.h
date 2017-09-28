#ifndef _ASM_X86_AKAROS_PARA_H
#define _ASM_X86_AKAROS_PARA_H

#ifdef CONFIG_AKAROS_GUEST
bool akaros_para_available(void);
bool akaros_para_top(void);
#else
static inline bool akaros_para_available(void)
{
	return false;
}

static inline bool akaros_para_top(void)
{
	return false;
}
#endif /* CONFIG_AKAROS_GUEST */

#endif /* _ASM_X86_AKAROS_PARA_H */
