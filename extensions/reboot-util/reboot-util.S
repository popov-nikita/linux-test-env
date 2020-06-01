	.section	.text,"ax",@progbits

	.globl		start
	.type		start,@function
start:
	movl		$.L__NR_reboot,%eax
	movl		$0xfee1dead,%edi
	movl		$672274793,%esi
	movl		$0x01234567,%edx
	syscall

	/*
		Normally, this is no-return action.
		But if we do...
	*/
	movl		$.L__NR_exit,%eax
	movl		$1,%edi
	syscall

	.size		start,. - start
