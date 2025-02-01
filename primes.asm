; WARNING: The code you are about to see contains cryptic variables, confusing logic,
; tons of magic numbers and obscure functions. Attempting to understand it may result in
; headaches, insomnia, depression and/or anxiety. Discretion advised, continue at your own risk.

bits 64
default rel

section .data
    prompt      db "Largest number to check? ", 0x0
    pmpt_len    equ $ - prompt

    found_msg   db "Found: ", 0x0
    fmsg_len    equ $ - found_msg

    time_msg_1  db "Elapsed time: ", 0x0
    t_msg_1_len equ $ - time_msg_1
    time_msg_2  db "ms", 0xA, 0x0
    t_msg_2_len equ $ - time_msg_2

    new_line    db 0xA, 0x0
    
    max_check   dq 0x0
    found       dq 0x0
    cached      dq 0x0

    ; string buffer, used to store numbers temporarily for printing
    int_buffer  db 0xC dup(0x0)
    buff_len    equ $ - int_buffer

    ; stores multiple numbers at once for printing
    prt_buffer  db 0x15F6 dup(0x0)
    prt_len     equ $ - prt_buffer

    ; input and output handles, for printing and reading input
    in_handle   dq 0x0
    out_handle  dq 0x0

    ; used for calculating execution time
    start_time  dq 0x0
    end_time    dq 0x0
    duration    dq 0x0

    ; booleans, they are qwords to avoid problems with comparison and register sizes
    FALSE       dq 0x0
    TRUE        dq 0xFF

section .text
    ; Windows API functions
    extern      ExitProcess
    extern      GetStdHandle
    extern      ReadFile
    extern      WriteFile
    ; C functions
    extern      strcat
    extern      strtol
    extern      _itoa
    extern      clock

    global      _start

_start:
    push        rbp
    mov         rbp, rsp
    sub         rsp, 0x20

    ; get input and output handles
    mov         rcx, -0xA
    call        GetStdHandle
    mov         [in_handle], rax
    mov         rcx, -0xB
    call        GetStdHandle
    mov         [out_handle], rax

    mov         rcx, [out_handle]
    mov         rdx, prompt
    mov         r8, pmpt_len
    call        WriteFile

    mov         rcx, [in_handle]
    lea         rdx, int_buffer
    mov         r8, buff_len
    call        ReadFile

    ; measure current time
    call        clock
    mov         [start_time], rax

    ;convert max number to integer
    mov         rcx, int_buffer
    xor         rdx, rdx
    mov         r8, 0xA
    call        strtol
    mov         [max_check], rax

    ; clear number string buffer
    mov         rdi, int_buffer
    mov         rcx, buff_len
    mov         rax, 0x0
    rep         stosb

    ; fun stuff
    mov         rcx, [max_check]
    call        printPrimes

    ; calculate execution time
    call        clock
    mov         [end_time], rax
    mov         rax, [end_time]
    sub         rax, [start_time]
    mov         [duration], rax

    ; end message
    mov         rcx, [out_handle]
    mov         rdx, found_msg
    mov         r8, fmsg_len
    xor         r9, r9
    call        WriteFile

    mov         rcx, [found]
    lea         rdx, int_buffer
    mov         r8, 0xA ; number base
    call        _itoa

    mov         rcx, int_buffer
    mov         rdx, new_line
    xor         r8, r8
    call        strcat

    mov         rcx, [out_handle]
    mov         rdx, int_buffer
    mov         r8, buff_len
    xor         r9, r9
    call        WriteFile

    mov         rdi, int_buffer
    mov         rcx, buff_len
    mov         rax, 0x0
    rep         stosb

    ; display execution time
    mov         rcx, [out_handle]
    mov         rdx, time_msg_1
    mov         r8, t_msg_1_len
    call        WriteFile

    mov         rcx, [duration]
    lea         rdx, int_buffer
    mov         r8, 0xA
    call        _itoa

    mov         rcx, [out_handle]
    mov         rdx, int_buffer
    mov         r8, buff_len
    xor         r9, r9
    call        WriteFile

    mov         rcx, [out_handle]
    mov         rdx, time_msg_2
    mov         r8, t_msg_2_len
    call        WriteFile

    xor         rax, rax
    call        ExitProcess
    

printPrimes:
    push        rbp
    mov         rbp, rsp
    sub         rsp, 0x20

    mov         r14, 0x1 ; counter var
    mov         r15, rcx ; max int to check

.printLoop:
    cmp         r14, r15
    jg          .allPrinted

    mov         rcx, r14
    call        checkIfPrime
    test        rax, rax
    jnz         .foundPrime

    inc         r14
    jmp         .printLoop

.foundPrime:
    ; convert
    mov         rcx, r14
    lea         rdx, int_buffer
    mov         r8, 0xA
    call        _itoa

    ; faster than an additional strcat call
    mov         rcx, int_buffer
    call        countDigits
    lea         rbx, [int_buffer]
    mov         byte [rbx + rax], 0xA ; int buffer pointer + digit count = position to add new line

    ; add to buffer
    mov         rcx, prt_buffer
    mov         rdx, int_buffer
    xor         r8, r8
    call        strcat

    inc         r14
    inc         qword [found]
    inc         qword [cached]

.addedNumber:
    ; print after adding n numbers to buffer
    cmp        qword [cached], 0x1FF
    jng        .printLoop

    mov         rcx, [out_handle]
    mov         rdx, prt_buffer
    mov         r8, prt_len
    xor         r9, r9
    call        WriteFile

    mov         rdi, prt_buffer
    mov         rcx, prt_len
    mov         rax, 0x0
    rep         stosb

    mov         qword [cached], 0x0

    jmp         .printLoop

.allPrinted:
    mov         rcx, [out_handle]
    mov         rdx, prt_buffer
    mov         r8, prt_len
    xor         r9, r9
    call        WriteFile

    mov         rdi, prt_buffer
    mov         rcx, prt_len
    mov         rax, 0x0
    rep         stosb

    mov         rsp, rbp
    pop         rbp
    ret

countDigits:
    push        rbp
    mov         rbp, rsp
    sub         rsp, 0x20

    mov         r12, 0xA ; digit counter
    lea         r13, [int_buffer + buff_len - 3] ; buffer length - 1 is NUL, -2 is reserved for new line, -3 is the last number digit

.countLoop:
    cmp         byte [r13], 0x0 ; check if char is NUL
    jnz         .endCount

    dec         r12
    dec         r13
    jmp         .countLoop

.endCount:
    mov         rax, r12
    
    mov         rsp, rbp
    pop         rbp
    ret


checkIfPrime:
    push        rbp
    mov         rbp, rsp
    sub         rsp, 0x20

    cmp         rcx, 0x2
    jl          .notPrime
    jg          .caseGreater

    mov         rax, [TRUE]

    mov         rsp, rbp
    pop         rbp
    ret

.notPrime:
    mov         rax, [FALSE]
    
    mov         rsp, rbp
    pop         rbp
    ret

.caseGreater:
    test        rcx, 0x1
    jz          .notPrime

    mov         r8, 0x3 ; counter for loop

    ; precompute sqrt of number, thx StackOverflow
    ; source: https://stackoverflow.com/a/35748220
    cvtsi2sd    xmm0, rcx
    sqrtsd      xmm0, xmm0     ; sd means scalar double, as opposed to SIMD packed double
    cvttsd2si   r9, xmm0     ; convert with truncation (C-style cast)

.checkDivisors:
    cmp         r8, r9
    jg          .noDivisors

    xor         rdx, rdx
    mov         rax, rcx
    mov         rbx, r8
    div         rbx
    test        rdx, rdx
    jz          .notPrime

    add         r8, 0x2
    jmp         .checkDivisors

.noDivisors:
    mov         rax, [TRUE]

    mov         rsp, rbp
    pop         rbp
    ret
