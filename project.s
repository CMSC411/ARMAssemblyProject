	.equ SWI_Open, 0x66 @open a file
	.equ SWI_Close,0x68 @close a file
	.equ SWI_PrChr,0x00 @ Write an ASCII char to Stdout
	.equ SWI_PrStr, 0x69 @ Write a null-ending string
	.equ SWI_PrInt,0x6b @ Write an Integer
	.equ SWI_RdInt,0x6c @ Read an Integer from a file
	.equ Stdout, 1 @ Set output target to be Stdout
	.equ SWI_Exit, 0x11 @ Stop execution
	.global _start
	.text
	value1: 
		.asciz "123.697"
		.set value1_size, .-value1
	value2: 
		.asciz "-543.631"
		.set value2_size, .-value2


@fUNCTIONS

getFirstBit:
	stmdb sp!, {R2, R3}		@store the registers we're going to use
	LDRB R2, [R0, #0]		@Get first byte
	mov R3, #0				@prep zero for R3
	cmp R2, #'-'			@is it a negative sign?
	moveq R3, #1			@if it's negative, use r instead			
	str R3, [R1, #0]			@store result in first number byte
	ldmia sp!, {R2, R3}		@pop the registers we're going to use
	bx lr                   @return

getDecimal:
	stmdb sp!, {R3, R4, R5, R6, lr}	@store what we use on the stack	
	mov R3, #1	@set base 10 multiplier
	mov R7,	#10	@just a constant		
	mov R5, #0	@value to put in memory

startDecimal:
	LDRB R8, [R0, R2]	@get ith bit in string
	cmp R8, #46         	@is it the decimal point?
	beq endDecimal      @end
	sub R4, R8, #48		@subtract 48 from ascii value to get int value
	mul R6, R3, R4		@base 10 * value of digit
	add R5, R5, R6		@add result
	mul R3, R7, R3		@increment base 10 counter
	sub R2, R2, #1		@increment source by 1			
	b startDecimal

endDecimal:
	str R5, [R1, #8]	@store result
	sub R2, R2, #1
	ldmia sp!, {R3, R4, R5, R6, lr}		@pop the registers we used
	bx lr

getWhole:
	stmdb sp!, {R3, R4, R5, R6, lr}	@store what we use on the stack	
	mov R3, #1	@set base 10 multiplier
	mov R7,	#10	@just a constant		
	mov R5, #0	@value to put in memory

startWhole:
	LDRB R8, [R0, R2]	@get ith bit in string
	cmp R2, #0         @is it the decimal point?
	blt endWhole      	@end
	sub R4, R8, #48		@subtract 48 from ascii value to get int value
	mul R6, R3, R4		@base 10 * value of digit
	add R5, R5, R6		@add result
	mul R3, R7, R3		@increment base 10 counter
	sub R2, R2, #1		@increment source by 1			
	b startWhole

endWhole:
	str R5, [R1, #4]	@store result
	ldmia sp!, {R3, R4, R5, R6, lr}		@pop the registers we used
	bx lr

_start:
	@get sign bit for first number
	ldr R0,=value1 @Set R0 to value1 pointer
	ldr R1,=value1Result		@load up bit for firstValue

	bl getFirstBit

	@get sign bit for second number
	ldr R0,=value2 @Set R0 to value1 pointer	
	ldr R1,=value2Result		@load up bit for firstValue

	bl getFirstBit

	ldr R0,=value1 @Set R0 to value1 pointer
	ldr R1,=value1Result		@load up bit for firstValue
	mov R2, #value1_size
	sub R2, R2, #2 @need to decrement by 2
	bl getDecimal
	bl getWhole

	ldr R0,=value2 @Set R0 to value1 pointer
	ldr R1,=value2Result		@load up bit for firstValue
	mov R2, #value2_size
	sub R2, R2, #2 @need to decrement by 2
	bl getDecimal
	bl getWhole


END:
	swi SWI_Exit
	.data

value1Result: .word 0, 0, 0
value2Result: .word 0, 0, 0
	
	.end