.equ SWI_Open, 0x66 	@ Open a file
.equ SWI_Close, 0x68 	@ Close a file
.equ SWI_PrChr, 0x00 	@ Write an ASCII char to Stdout
.equ SWI_PrStr, 0x69	@ Write a null-ending string
.equ SWI_PrInt, 0x6b 	@ Write an Integer
.equ SWI_RdInt, 0x6c 	@ Read an Integer from a file
.equ Stdout, 1 			@ Set output target to be Stdout
.equ SWI_Exit, 0x11 	@ Stop execution

.global _start

@ INPUT VALUES
.text
	value1: 
		.asciz "+1000.0"			@ first value (string)
		.set value1_size, .-value1 	@ size of first value
	value2: 
		.asciz "+3000.2" 			@ second value (string)
		.set value2_size, .-value2 	@ size of second value

@ FUNCTIONS
getFirstBit:
	stmdb sp!, {R2, R3}		@ store the registers we're going to use
	ldrb R2, [R0, #0]		@ Get first byte
	mov R3, #0				@ prep zero for R3
	cmp R2, #'-'			@ is it a negative sign?
	moveq R3, #1			@ if it's negative, use r instead			
	str R3, [R1, #0]		@ store result in first number byte
	ldmia sp!, {R2, R3}		@ pop the registers we're going to use
	bx lr                   @ return

getDecimal:
	stmdb sp!, {R3, R4, R5, R6, lr}	@ store what we use on the stack	
	mov R3, #1	@ set base 10 multiplier
	mov R7,	#10	@ just a constant		
	mov R5, #0	@ value to put in memory

	startDecimal:
		ldrb R8, [R0, R2]	@ get ith bit in string
		cmp R8, #46         @ is it the decimal point?
		beq endDecimal      @ end
		sub R4, R8, #48		@ subtract 48 from ascii value to get int value
		mul R6, R3, R4		@ base 10 * value of digit
		add R5, R5, R6		@ add result
		mul R3, R7, R3		@ increment base 10 counter
		sub R2, R2, #1		@ increment source by 1			
		b startDecimal 		@ loops back

	endDecimal:
		str R5, [R1, #8]	@ store result
		sub R2, R2, #1		@ subtract 
		ldmia sp!, {R3, R4, R5, R6, lr}		@ pop the registers we used
		bx lr 	@ return			

getWhole:
	stmdb sp!, {R3, R4, R5, R6, lr}	@ store what we use on the stack	
	mov R3, #1	@ set base 10 multiplier
	mov R7,	#10	@ just a constant		
	mov R5, #0	@ value to put in memory

	startWhole:
		ldrb R8, [R0, R2]	@ get ith bit in string
		cmp R2, #0			@ is it the decimal point?
		beq endWhole      	@ end
		sub R4, R8, #48		@ subtract 48 from ascii value to get int value
		mul R6, R3, R4		@ base 10 * value of digit
		add R5, R5, R6		@ add result
		mul R3, R7, R3		@ increment base 10 counter
		sub R2, R2, #1		@ increment source by 1			
		b startWhole		@ loops back

	endWhole:
		str R5, [R1, #4]	@ store result
		ldmia sp!, {R3, R4, R5, R6, lr}	@ pop the registers we used
		bx lr 	@ return

splitIEE754:
	stmdb sp!, {R3, R4, R5, lr} @store registers
	ldr R3, [R1]	@load answer into R3
	ldr R4, [R0] 	@load value of input
	mov R5, R4, LSR #31	@ get sign
	str R5, [R1, #0]	@store sign
	mov R4, R4, LSL #1	@get everything but sign
	mov R4, R4, LSR #1	@shift back right
	mov R5, R4, LSR #23	@get exponent
 	str R5, [R1, #4]	@store exponent
 	mov R4, R4, LSL #9	@delete exponent
 	mov R4, R4, LSR #9	@remaining value is mantissa
 	str R4, [R1, #8]	@store exponent
	ldmia sp!, {R3, R4, R5, lr}	@ pop the registers we used
	bx lr 	@ return

add_: @expects value1 in R0, value2 in R1, and result location in R2
	stmdb sp!, {R3, R4, R5, R6, R7, R8, R9, lr} @store registers
	
	ldr R3, [R0] @get sign of first value
	ldr R4, [R1] @get sign of second value
	
	cmp R3, R4 
	beq same_sign @jump to same_sign if equal
	b diff_sign   @jump to diff if diff

	same_sign:
		str R3, [R2] @store new sign (same)
		mov R7, #4   @offset for getting exp
		ldr R3, [R0, R7] @get exp for both values
		ldr R4, [R1, R7]
	
		mov R7, #8			@get mantissa for both values
		ldr R5, [R0, R7]
		ldr R6, [R1, R7]

		mov R7, #1			@R7 used here to add 'assumed' 1 back to mantissa
		mov R7, R7, LSL #31

		mov R5, R5, LSL #8	@shift left 8, leaving a space for the 'assumed' 1
		add R5, R5, R7		@add assumed 1
		mov R6, R6, LSL #8	
		add R6, R6, R7

		mov R5, R5, LSR #1 @shift right 1 to leave a space for carry
		mov R6, R6, LSR #1

		cmp R4, R3		@jump to add if exp are equal
		beq mant_add

		cmp R3, R4		@jump to shift_mant if first exponent larger than second
		bhi shift_mant

		mov R7, R3		@if second exponent larger, flip around exp and mantissa in registers
		mov R3, R4
		mov R4, R7
		mov R7, R5
		mov R5, R6
		mov R6, R7

		shift_mant:				@calculate difference in exponent, then shift mantissa accordingly
			sub R7, R3, R4
			mov R6, R6, LSR R7

		mant_add:					@add both mantissas
			add R7, R5, R6
			mov R8, R7				@R8 contains leftmost bit of result
			mov R8, R8, LSR #31
			mov R9, #1
			cmp R8, R9				@if leftmost bit of result is 0, no overflow so end
			bne end_add

			add R3, R3, #1			@leftmost bit is 1, so add 1 to exponent and shift mantissa 1
			mov R7, R7, LSR #1

		end_add:					@store the exponent
			str R3, [R2, #4]
			mov R7, R7, LSL #2		@shift left 2 to get rid of 'assumed' 1
			mov R7, R7, LSR #9		@shift right 9 to get back to desired form
			str R7, [R2, #8]		@store mantissa
			ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
			bx lr 	@ return

	diff_sign:					@if signs are different (subtract)
		cmp R3, #1				
		beq first_neg			@if first value is negative
		b second_neg			@if second value is negative

		first_neg:				@first value is negative
			mov R9, #4
			ldr R5, [R0, R9]	@load in exponents
			ldr R6, [R1, R9]

			mov R9, #8			@load in mantissas
			ldr R7, [R0, R9]
			ldr R8, [R1, R9]

			cmp R5, R6					@compare exponents
			beq check_mant_first		@if exponents equal, check mantissas
			
			cmp R5, R6					@compare exponents
			bhi	neg_result_first		@if exponent of negative value is higher
			b pos_result_first

			check_mant_first:			@compare mantissas
				cmp R7, R8
				bls pos_result_first	@if positive mantissa is higher or equal
				b neg_result_first		@if negative mantissa is higher

			neg_result_first: 
				str R3, [R2]			@store negative
				b continue

			pos_result_first:
				str R4, [R2]			@store positive
				b continue

		second_neg:				@second value is negative
			mov R9, #4
			ldr R5, [R0, R9]	@load in exponents
			ldr R6, [R1, R9]

			mov R9, #8			@load in mantissas
			ldr R7, [R0, R9]
			ldr R8, [R1, R9]

			cmp R5, R6					@compare exponents
			beq check_mant_second		@if exponents equal, check mantissas
			
			cmp R5, R6					@compare exponents
			bhi	pos_result_second		@if exponent of positive value is higher
			b neg_result_second

			check_mant_second:			@compare mantissas
				cmp R8, R7
				bls pos_result_second	@if positive value is higher or equal
				b neg_result_second		@if negative value is higher

			neg_result_second: 
				str R4, [R2]			@store negative
				b continue

			pos_result_second:
				str R3, [R2]			@store positive

			continue:
				mov R7, #4				@reload exponents and mantissas into different registers
				ldr R3, [R0, R7]
				ldr R4, [R1, R7]
	
				mov R7, #8
				ldr R5, [R0, R7]
				ldr R6, [R1, R7]

				mov R7, #1
				mov R7, R7, LSL #31		@set up value to add back in 'assumed' 1

				mov R5, R5, LSL #8		@add back in assumed 1
				add R5, R5, R7
				mov R6, R6, LSL #8	
				add R6, R6, R7

				cmp R4, R3				@if exponents are equal
				beq mant_sub_f

				cmp R4, R3				@if second exponent is larger
				bhi second_exp_larger
				b first_exp_larger		@if first exponent is larger
				
				first_exp_larger:
					sub R7, R3, R4		@calculate shift
					mov R6, R6, LSR R7
					b mant_sub_f		@jump to mantissa for first exp larger
				second_exp_larger:
					sub R7, R4, R3		@calculate shift
					mov R5, R5, LSR R7
					b mant_sub_s		@jump to mantissa for second exp larger

				mant_sub_f:				@subtract mantissas for first exp larger
					sub R7, R5, R6
					mov R6, #31			@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6	@shift R8 right by R6
					mov R5, #0			@number to add to exp
					mov R9, #0			
					cmp R8, R9			@check if R8 is 0
					bne end_sub_f		@if 1 is found, jump to end
					b new_exp_f			@if still 0, jump to new_exp
					
				mant_sub_s:				@same as above bot second exp larger
					sub R7, R6, R5
					mov R6, #31
					mov R8, R7
					mov R8, R8, LSR R6
					mov R5, #0
					mov R9, #0
					cmp R8, R9
					bne end_sub_s
					b new_exp_s
					
				end_sub_f:				@end for first exp larger
					sub R3, R3, R5		@reduce exponent
					str R3, [R2, #4]	@store exponent
					add R5, R5, #1		
					mov R7, R7, LSL R5	@shift mantissa left to get normalized
					mov R7, R7, LSR #9	@shift right to put back in desired form
					str R7, [R2, #8]	@store mantissa
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return

				end_sub_s:				@same as above for second exp larger
					sub R4, R4, R5
					str R4, [R2, #4]
					add R5, R5, #1
					mov R7, R7, LSL R5
					mov R7, R7, LSR #9
					str R7, [R2, #8]
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return
				
				end_zero:				@result was 0
					str R6, [R2]
					str R6, [R2, #4]
					str R6, [R2, #8]
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return

				new_exp_f:				@first exp larger, keep shifting until 1 is found
					sub R6, R6, #1		@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6  @shift R8 right by R6
					add R5, R5, #1		@number to add to exp
					cmp R8, R9			
					bne end_sub_f		@if 1 is found go to end
					cmp R6, #0			@if mantissa is 0, go to end for 0
					beq end_zero
					b new_exp_f			@if R6 not 0 keep looping



				new_exp_s:				@second exp larger, keep shifting until 1 is found
					sub R6, R6, #1		@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6	@shift R8 right by R6
					add R5, R5, #1		@number to add to exp
					cmp R8, R9
					bne end_sub_s		@if 1 is found go to end
					cmp R6, #0			@if mantissa is 0, go to end for 0
					beq end_zero
					b new_exp_s			@if R6 not 0 keep looping

sub_: @expects value1 in R0, value2 in R1, and result location in R2
	stmdb sp!, {R3, R4, R5, R6, R7, R8, R9, lr} @store registers
	
	ldr R3, [R0] @get sign of first value
	ldr R4, [R1] @get sign of second value
	
	cmp R3, R4 
	bne diff_sign_ @jump to diff_sign if equal
	b same_sign_   @jump to same if diff

	diff_sign_:
		str R3, [R2] @store new sign (same)
		mov R7, #4   @offset for getting exp
		ldr R3, [R0, R7] @get exp for both values
		ldr R4, [R1, R7]
	
		mov R7, #8			@get mantissa for both values
		ldr R5, [R0, R7]
		ldr R6, [R1, R7]

		mov R7, #1			@R7 used here to add 'assumed' 1 back to mantissa
		mov R7, R7, LSL #31

		mov R5, R5, LSL #8	@shift left 8, leaving a space for the 'assumed' 1
		add R5, R5, R7		@add assumed 1
		mov R6, R6, LSL #8	
		add R6, R6, R7

		mov R5, R5, LSR #1 @shift right 1 to leave a space for carry
		mov R6, R6, LSR #1

		cmp R4, R3		@jump to add if exp are equal
		beq mant_add_

		cmp R3, R4		@jump to shift_mant if first exponent larger than second
		bhi shift_mant_

		mov R7, R3		@if second exponent larger, flip around exp and mantissa in registers
		mov R3, R4
		mov R4, R7
		mov R7, R5
		mov R5, R6
		mov R6, R7

		shift_mant_:				@calculate difference in exponent, then shift mantissa accordingly
			sub R7, R3, R4
			mov R6, R6, LSR R7

		mant_add_:					@add both mantissas
			add R7, R5, R6
			mov R8, R7				@R8 contains leftmost bit of result
			mov R8, R8, LSR #31
			mov R9, #1
			cmp R8, R9				@if leftmost bit of result is 0, no overflow so end
			bne end_add_

			add R3, R3, #1			@leftmost bit is 1, so add 1 to exponent and shift mantissa 1
			mov R7, R7, LSR #1

		end_add_:					@store the exponent
			str R3, [R2, #4]
			mov R7, R7, LSL #2		@shift left 2 to get rid of 'assumed' 1
			mov R7, R7, LSR #9		@shift right 9 to get back to desired form
			str R7, [R2, #8]		@store mantissa
			ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
			bx lr 	@ return

	same_sign_:					@if signs are same (subtract)
		cmp R3, #1				
		beq first_neg_			@if first value is negative
		b second_neg_			@if second value is negative

		first_neg_:				@first value is negative
			mov R9, #4
			ldr R5, [R0, R9]	@load in exponents
			ldr R6, [R1, R9]

			mov R9, #8			@load in mantissas
			ldr R7, [R0, R9]
			ldr R8, [R1, R9]
			
			mov R9, #0			

			cmp R5, R6					@compare exponents
			beq check_mant_first_		@if exponents equal, check mantissas
			
			cmp R5, R6					@compare exponents
			bhi	neg_result_first_		@if exponent of negative value is higher
			b pos_result_first_

			check_mant_first_:			@compare mantissas
				cmp R7, R8
				bls pos_result_first_	@if positive mantissa is higher or equal
				b neg_result_first_		@if negative mantissa is higher

			neg_result_first_: 
				str R3, [R2]			@store negative
				b continue_

			pos_result_first_:
				str R9, [R2]			@store positive
				b continue_

		second_neg_:				@second value is negative
			mov R9, #4
			ldr R5, [R0, R9]	@load in exponents
			ldr R6, [R1, R9]

			mov R9, #8			@load in mantissas
			ldr R7, [R0, R9]
			ldr R8, [R1, R9]
			
			mov R9, #1

			cmp R5, R6					@compare exponents
			beq check_mant_second_		@if exponents equal, check mantissas
			
			cmp R5, R6					@compare exponents
			bhi	pos_result_second_		@if exponent of positive value is higher
			b neg_result_second_

			check_mant_second_:			@compare mantissas
				cmp R8, R7
				bls pos_result_second_	@if positive value is higher or equal
				b neg_result_second_		@if negative value is higher

			neg_result_second_: 
				str R9, [R2]			@store negative
				b continue_

			pos_result_second_:
				str R3, [R2]			@store positive

			continue_:
				mov R7, #4				@reload exponents and mantissas into different registers
				ldr R3, [R0, R7]
				ldr R4, [R1, R7]
	
				mov R7, #8
				ldr R5, [R0, R7]
				ldr R6, [R1, R7]

				mov R7, #1
				mov R7, R7, LSL #31		@set up value to add back in 'assumed' 1

				mov R5, R5, LSL #8		@add back in assumed 1
				add R5, R5, R7
				mov R6, R6, LSL #8	
				add R6, R6, R7

				cmp R4, R3				@if exponents are equal
				beq mant_sub_f_

				cmp R4, R3				@if second exponent is larger
				bhi second_exp_larger_
				b first_exp_larger_		@if first exponent is larger
				
				first_exp_larger_:
					sub R7, R3, R4		@calculate shift
					mov R6, R6, LSR R7
					b mant_sub_f_		@jump to mantissa for first exp larger
				second_exp_larger_:
					sub R7, R4, R3		@calculate shift
					mov R5, R5, LSR R7
					b mant_sub_s_		@jump to mantissa for second exp larger

				mant_sub_f_:				@subtract mantissas for first exp larger
					sub R7, R5, R6
					mov R6, #31			@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6	@shift R8 right by R6
					mov R5, #0			@number to add to exp
					mov R9, #0			
					cmp R8, R9			@check if R8 is 0
					bne end_sub_f_		@if 1 is found, jump to end
					b new_exp_f_		@if still 0, jump to new_exp
					
				mant_sub_s_:				@same as above bot second exp larger
					sub R7, R6, R5
					mov R6, #31
					mov R8, R7
					mov R8, R8, LSR R6
					mov R5, #0
					mov R9, #0
					cmp R8, R9
					bne end_sub_s_
					b new_exp_s_
					
				end_sub_f_:				@end for first exp larger
					sub R3, R3, R5		@reduce exponent
					str R3, [R2, #4]	@store exponent
					add R5, R5, #1		
					mov R7, R7, LSL R5	@shift mantissa left to get normalized
					mov R7, R7, LSR #9	@shift right to put back in desired form
					str R7, [R2, #8]	@store mantissa
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return

				end_sub_s_:				@same as above for second exp larger
					sub R4, R4, R5
					str R4, [R2, #4]
					add R5, R5, #1
					mov R7, R7, LSL R5
					mov R7, R7, LSR #9
					str R7, [R2, #8]
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return
				
				end_zero_:				@result was 0
					str R6, [R2]
					str R6, [R2, #4]
					str R6, [R2, #8]
					ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pop the registers we used
					bx lr 	@ return

				new_exp_f_:				@first exp larger, keep shifting until 1 is found
					sub R6, R6, #1		@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6  @shift R8 right by R6
					add R5, R5, #1		@number to add to exp
					cmp R8, R9			
					bne end_sub_f_		@if 1 is found go to end
					cmp R6, #0			@if mantissa is 0, go to end for 0
					beq end_zero_
					b new_exp_f_			@if R6 not 0 keep looping



				new_exp_s_:				@second exp larger, keep shifting until 1 is found
					sub R6, R6, #1		@R6 = amount to shift to get leftmost bit
					mov R8, R7			@put result in R8
					mov R8, R8, LSR R6	@shift R8 right by R6
					add R5, R5, #1		@number to add to exp
					cmp R8, R9
					bne end_sub_s_		@if 1 is found go to end
					cmp R6, #0			@if mantissa is 0, go to end for 0
					beq end_zero_
					b new_exp_s_			@if R6 not 0 keep looping

getIEEE754:
	stmdb sp!, {R2, R3, R4, R5, R6, R7, R8, R9, lr} @ stores registers on stack

	ldr R2, [R0, #0]	@ loads the sign bit into R2
	str R2, [R9, #0]	@ store sign bit in first word of split answer

	ldr R2, [R0, #4]	@ loads the whole number part into R2
	cmp R2, #1			@ is our whole number part 1?
	moveq R8, #0		@ if so, make our exponent answer 0
	moveq R5, #2		@ sets R5 to 2 so that the mantissa part works correctly
	beq exponentInBin	@ also if so, jump to the exponent conversion

	mov R5, #2 			@ our 2^(R8+1) number
	mov R6, #2			@ stays 2 to multiply R6 by 2 each iteration
	mov R8, #0			@ our exponent answer
	findExponent:	
		cmp R2, R5			@ is our whole number < the current 2^(R8+1)? 
		blt exponentInBin 	@ if so, proceed to exponent conversion
		add R8, R8, #1		@ otherwise, adds one to our exponent
		mul R7, R5, R6		@ and multiplies our 2^x number by 2
		mov R5, R7			@ and moves the answer into the correct spot
		b findExponent		@ loops back

	exponentInBin:
		add R8, R8, #127	@ adds 127 to the exponent
		str R8, [R9, #4]	@ stores the exponent in the second word of the split answer
		sub R8, R8, #127	@ restores the original exponent

	mantissaInBin:
		mov R5, R5, LSR #1	@ divides our 2^(R8+1) number by 2
		sub R2, R2, R5		@ takes the previous number off of our whole number in order to remove the leading 1 bit
		mov R3, R2			@ place whole number in where the mantissa will be
		rsb R8, R8, #23     @ finds how much space we have for the decimal

		mov R4, #1			@ our iterator
		mov R6, #0			@ count for how many base 10 digits our number is
		mov R7, #10			@ stays as 10 to multiply R4 by 10 each iteration
		ldr R2, [R0, #8]	@ loads the decimal part into R2
		digitCount:
			cmp R2, R4			@ is our decimal part greater than 10^R4?
			mulge R5, R4, R7	@ if so, multiply R4 by 10
			addge R6, R6, #1	@ add one to the count
			movge R4, R5		@ move the product into R4 to start again
			bge digitCount 		@ loops back

		convertFraction:
			cmp R8, #0				@ are we done looping
			beq finishIEEE754		@ if so, exit loop
			mov R2, R2, LSL #1		@ multiply our fraction number by 2
			cmp R2, R4				@ have we overflowed into a new decimal digit?
			subgt R2, R2, R4		@ if so, subtract off that digit
			movgt R3, R3, LSL #1	@ also, shift over the mantissa
			addgt R3, R3, #1		@ also, add one to the mantissa
			subgt R8, R8, #1		@ also, take one from the loop counter
			bgt convertFraction		@ also, loop back
			movlt R3, R3, LSL #1	@ if not, shift over the mantissa
			sublt R8, R8, #1		@ also, take one from the loop counter
			blt convertFraction		@ also, loop back
			moveq R3, R3, LSL #1	@ if we equaled "1" per se, shift left one
			addeq R3, R3, #1		@ also, add one to the mantissa
			subeq R8, R8, #1		@ also, subtract one from the loop count
			moveq R3, R3, LSL R8	@ also, fill the rest of the mantissa with 0's
			beq finishIEEE754		@ also, skip to the end

	finishIEEE754:
		str R3, [R9, #8]	@ stores the mantissa into the split answer
		ldmia sp!, {R2, R3, R4, R5, R6, R7, R8, R9, lr}	@ pops registers from stack
		bx lr 			@ return

IEEE754ThreeWordsToOne:
	stmdb sp!, {R0, R2, lr} @ stores registers on stack
	ldr R0, [R9, #0]		@ place the sign bit in the register
	mov R0, R0, LSL #8		@ move over 8 bits for the exponent
	ldr R2, [R9, #4]		@ load the exponent into R2
	add R0, R0, R2			@ place the exponent in the register
	mov R0, R0, LSL #23		@ move over 23 bits for the mantissa
	ldr R2, [R9, #8]		@ load the mantissa into R2
	add R0, R0, R2			@ place the mantissa in the register
	str R0, [R1]			@ store the IEEE 754 number in the word
	ldmia sp!, {R0, R2, lr}	@ pops registers from stack
	bx lr 

multiply:
	@@@GET SIGN BIT
	stmdb sp!, {R3, R4, R5, R6, R7, R8, R9, lr} @store registers
	ldr R3, [R0] @get sign of first value
	ldr R4, [R1] @get sign of second value
	eor R5, R3, R4	@should sign be 1 or 0?
	str R5, [R2, #0] @store sign

	@add exponents
	ldr R3, [R0, #4] @load exponent of first value
	ldr R4, [R1, #4] @load exponent of second value
	add R3, R3, R4	 @sum the bits
	sub R3, R3, #127 @subtract 127

	@determine mantissa
	ldr R4, [R0, #8] @load mantisa value 1
	ldr R5, [R1, #8] @load mantisa value 2

	mov R7, #1			@R7 used here to add 'assumed' 1 back to mantissa
	mov R7, R7, LSL #31

	mov R4, R4, LSL #8	@shift left 8, leaving a space for the 'assumed' 1
	add R4, R4, R7		@add assumed 1
	mov R4, R4, LSR #9	@shift back right

	mov R5, R5, LSL #8	@shift left 8, leaving a space for the 'assumed' 1
	add R5, R5, R7      @add assumed 1
	mov R5, R5, LSR #9	@shift back right

	mov R9, #0	@result
	addMantissa:
		mov R6, R4, LSL #31 @check lsb of value2
		cmp R6, #0 @is it zero or one?
		addne R9, R9, R5	@add by value1
		mov R4, R4, LSR #1	@shift value
		mov R9, R9, LSR #1	@shift result
		cmp R4, #0 @have we shifted out all of value2
		bne addMantissa

	endmul:
		mov R6, #4194304 @load max 23 bit number
		cmp R9, R6 @is our number greater?
		addgt R3, R3, #1 @need to increment exponent
		movgt R9, R9, LSR #1 @shift right so we're not overflowing
		mov R9, R9, LSL #11 @kill sign bit
		mov R9, R9, LSR #9 @shift back into place
		str R3, [R2, #4] @store exponent
		str R9, [R2, #8]	@store mantissa
		ldmia sp!, {R3, R4, R5, R6, R7, R8, R9, lr}	@ pops registers from stack
		bx lr 	@ return


@ MAIN
_start:
	@ get sign bit for first number
	ldr R0, =value1			@ Set R0 to value1 pointer
	ldr R1, =value1Result	@ load up bit for firstValue
	bl getFirstBit			@ gets the sign bit

	@ get sign bit for second number
	ldr R0, =value2 		@ Set R0 to value1 pointer	
	ldr R1, =value2Result	@ load up bit for firstValue
	bl getFirstBit			@ gets the sign bit

	@ gets the decimal and whole number parts for first number
	ldr R0, =value1 		@ Set R0 to value1 pointer
	ldr R1, =value1Result	@ load up bit for firstValue
	mov R2, #value1_size	@ moves the size of value1 into R2
	sub R2, R2, #2 			@ need to decrement by 2
	bl getDecimal			@ gets the decimal part
	bl getWhole				@ gets the whole part

	@ gets the decimal and whole number parts for second number
	ldr R0, =value2 		@ Set R0 to value1 pointer
	ldr R1, =value2Result	@ load up bit for firstValue
	mov R2, #value2_size	@ moves the size of value1 into R2
	sub R2, R2, #2 			@ need to decrement by 2
	bl getDecimal			@ gets the decimal part
	bl getWhole				@ gets the whole part

	@ converts value 1 into IEEE 754
	ldr R0, =value1Result	@ loads the parsed version of value 1 into R0
	ldr R1, =value1IEEE754	@ loads the answer pointer into R1
	ldr R9, =value1IEESplit @ load result
	bl getIEEE754			@ does the IEEE 754 conversion
	bl IEEE754ThreeWordsToOne	@ puts the IEEE 754 number in one word

	@ converts value 2 into IEEE 754
	ldr R0, =value2Result	@ loads the parsed version of value 2 into R0
	ldr R1, =value2IEEE754	@ loads the answer pointer into R1
	ldr R9, =value2IEESplit @ load result
	bl getIEEE754			@ does the IEEE 754 conversion
	bl IEEE754ThreeWordsToOne	@ puts the IEEE 754 number in one word

	ldr R0, =value1IEESplit
	ldr R1, =value2IEESplit
	ldr R2, =sumSplit
	bl add_

	ldr R0, =value1IEESplit
	ldr R1, =value2IEESplit
	ldr R2, =diffSplit
	bl sub_

	ldr R0, =value1IEESplit
	ldr R1, =value2IEESplit
	ldr R2, =productSplit
	bl multiply

	ldr R9, =sumSplit
	ldr R1, =sumIEE754
	bl IEEE754ThreeWordsToOne

	ldr R9, =diffSplit
	ldr R1, =diffIEE754
	bl IEEE754ThreeWordsToOne

	ldr R9, =productSplit
	ldr R1, =productIEE754
	bl IEEE754ThreeWordsToOne

	ldr R0, =value1IEEE754	@load address of value1
	ldr R1, =value2IEEE754	@load address of value2
	ldr R0, [R0]	@load value of value1
	ldr R1, [R1]	@load value of value1

	ldr R3, =sumNative	@load address of add result
	ldr R4, =diffNative	@load address of diff result
	ldr R5, =productNative	@load address of product result


	FMSR s0, r0 		;@ move floating point operand 1 into s0
	FMSR s1, r1 		;@ move floating point operand 2 into s1
	FADDS s2, s0, s1 	;@ perform floating point addition. store result into s2
	FMRS r2, s2 		;@ move result back into r2
	FSUBS s2, s0, s1 	;@ perform floating point subtraction. store result into s2
	FMRS r6, s2 		;@ move result back into r6
	FMULS s2, s0, s1 	;@ perform floating point multiply. store result into s2
	FMRS r7, s2 		;@ move result back into r7

	str R2, [R3]		@store addition result
	str R6, [R4]		@store subtraction result
	str R7, [R5]		@store multiplication result


END:
	swi SWI_Exit	@ exit program

.data
	value1Result: .word 0, 0, 0	@ holds a parsed version of the first value
	value2Result: .word 0, 0, 0	@ holds a parsed version of the second value

	value1IEESplit: .word 0, 0, 0   @ holds value 1 in IEEE, but split into Sign, Exponent, and Mantissa
	value2IEESplit: .word 0, 0, 0	@ holds value 2 in IEEE, but split into Sign, Exponent, and Mantissa
	sumSplit: .word 0, 0, 0	@ holds sum in IEEE, but split into Sign, Exponent, and Mantissa
	diffSplit: .word 0, 0, 0	@ holds diff in IEEE, but split into Sign, Exponent, and Mantissa
	productSplit: .word 0, 0, 0	@ holds diff in IEEE, but split into Sign, Exponent, and Mantissa
	
	value1IEEE754: .word 0		@ holds value 1 in IEEE 754 form
	value2IEEE754: .word 0		@ holds value 2 in IEEE 754 form

	sumIEE754: .word 0	@holds sum in IEE 754 Form
	sumNative: .word 0	@holds result of native summation

	diffIEE754: .word 0	@holds difference in IEE 754 Form
	diffNative: .word 0	@holds result of native subtraction

	productIEE754: .word 0	@holds product in IEE 754 Form
	productNative: .word 0	@holds result of native multiplication
	
.end