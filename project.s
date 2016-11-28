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
		.asciz "-12.0"			@ first value (string)
		.set value1_size, .-value1 	@ size of first value
	value2: 
		.asciz "-39887.5625" 			@ second value (string)
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


getIEEE754:
	stmdb sp!, {R2, R3, R4, R5, R6, R7, R8, lr} @ stores registers on stack
	
	ldr R4, [R1]		@ loads the answer's value into R4
	ldr R2, [R0, #0]	@ loads the sign bit into R2
	cmp R2, #1			@ do we have a negative number?
	addeq R3, R4, #1	@ if so, make the first bit of the answer 1

	ldr R2, [R0, #4]	@ loads the whole number part into R2
	cmp R2, #0			@ is our whole number part 0?
	moveq R8, #0		@ if so, make our exponent answer 0
	beq exponentInBin	@ also if so, jump to the exponent conversion

	mov R5, #2 			@ our 2^(R8+1) number
	mov R6, #2			@ stays 2 to multiply R6 by 2 each iteration
	mov R8, #0			@ our exponent answer
	findExponent:	
		cmp R2, R5			@ is our whole number <= the current 2^(R8+1)? 
		ble exponentInBin 	@ if so, proceed to exponent conversion
		add R8, R8, #1		@ otherwise, adds one to our exponent
		mul R7, R5, R6		@ and multiplies our 2^x number by 2
		mov R5, R7			@ and moves the answer into the correct spot
		b findExponent		@ loops back

	exponentInBin:
		mov R3, R3, LSL #8	@ shifts the answer's bit 8 positions to the left
		add R8, R8, #127	@ adds 127 to the exponent
		add R3, R3, R8		@ adds the exponent onto the end of the sign bit

	mantissaInBin:
		sub R8, R8, #126	@ restores the original exponent plus one
		mov R3, R3, LSL R8	@ shifts the answer by the exponent plus one bits
		add R3, R3, R2		@ adds the whole number part to end of the exponent
		sub R8, R8, #1		@ restores the original exponent
		rsb R8, R8, #23     	@ finds how much space we have for the decimal

		mov R4, #1			@ our iterator
		mov R6, #0			@ count for how many base 10 digits our number is
		mov R7, #10			@ stays as 10 to multiply R4 by 10 each iteration
		ldr R2, [R0, #8]	@ loads the decimal part into R2
		digitCount:
			cmp R2, R4			@ is our decimal part greater than 10^R4?
			mulgt R5, R4, R7	@ if so, multiply R4 by 10
			addgt R6, R6, #1	@ add one to the count
			movgt R4, R5		@ move the product into R4 to start again
			bgt digitCount 		@ loops back
		sub R8, R8, #1			@ makes R8 the number of 2 multiplications we need
		mov R2, R2, LSL R8		@ multiplies our fraction part by 2^R8
		add R8, R8, #1			@ adds back the one we just subtracted for later
		ldr R4, =0x1999999A		@ magic number for dividing by 10 bitwise
		divideByTens:
			cmp R6, #0 				@ do we still have to divide by 10?
			umullne R5, R7, R2, R4	@ if so, long multiplies our R2 by R4
			subne R6, R6, #1	@ also, subtracts one from the times we need to divide by 10
			movne R2, R7			@ moves the product into R2 for the loop
			bne divideByTens 		@ loops back

		mov R4, #1				@ our iterator
		mov R6, #0				@ counts how many binary digits our number is
		mov R7, #2				@ stays as 2 to multiply by R4 each iteration
		digitCountBin:
			cmp R2, R4			@ is our number greater than 2^R4?
			mulgt R5, R4, R7	@ if so, multiply by 2
			addgt R6, R6, #1    	@ also, add one to the count
			movgt R4, R5		@ moves the product back into R4 for looping
			bgt digitCountBin	@ loops back

		cmp R6, R8			@ do we have room for our decimal result?
		ble placeAndShift		@ if so, place it and shift over the rest
		bgt shiftAndPlace 		@ if not, truncate the number and place it

		@ NOTE: DOES NOT WORK YET
		placeAndShift:
			mov R3, R3, LSL R6	
			add R3, R3, R2
			sub R8, R8, R6
			@mov R3, R3, LSL R8

		shiftAndPlace:

	finishIEEE754:
		str R3, [R1]	@ stores the IEEE 754 number into memory
		ldmia sp!, {R2, R3, R4, R5, R6, R7, R8, lr}	@ pops registers from stack
		bx lr 			@ return



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
	bl getIEEE754			@ does the IEEE 754 conversion

	@ converts value 1 into IEEE 754
	ldr R0, =value2Result	@ loads the parsed version of value21 into R0
	ldr R1, =value2IEEE754	@ loads the answer pointer into R1
	bl getIEEE754			@ does the IEEE 754 conversion

	@split value up into different words
	ldr R0, =value1IEEE754	@ loads IEE754 version
	ldr R1, =value1IEESplit @load result
	bl splitIEE754

	@split value up into different words
	ldr R0, =value2IEEE754	@ loads IEE754 version
	ldr R1, =value2IEESplit @load result
	bl splitIEE754
END:
	swi SWI_Exit	@ exit program

.data
	value1Result: .word 0, 0, 0	@ holds a parsed version of the first value
	value2Result: .word 0, 0, 0	@ holds a parsed version of the second value
	value1IEEE754: .word 0		@ holds value 1 in IEEE 754 form
	value2IEEE754: .word 0		@ holds value 2 in IEEE 754 form
	value1IEESplit: .word 0, 0, 0   @ holds value 1 in IEEE, but split into Sign, Exponent, and Mantissa
	value2IEESplit: .word 0, 0, 0	@ holds value 2 in IEEE, but split into Sign, Exponent, and Mantissa
.end